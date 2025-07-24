import os
import jwt
import logging
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import msal
from jose import jwt as jose_jwt, JWTError
import aiohttp
import asyncio

logger = logging.getLogger(__name__)

class AzureADAuthValidator:
    def __init__(self):
        self.tenant_id = os.environ.get("AZURE_TENANT_ID")
        self.client_id = os.environ.get("AZURE_CLIENT_ID")
        self.authority = f"https://login.microsoftonline.com/{self.tenant_id}"
        self.jwks_uri = f"{self.authority}/discovery/v2.0/keys"
        self.issuer = f"https://sts.windows.net/{self.tenant_id}/"
        self.valid_audiences = [
            self.client_id,
            f"api://{self.client_id}"
        ]
        self._jwks_cache = None
        self._jwks_cache_time = None
        self._cache_duration = timedelta(hours=1)
        
    async def get_jwks(self) -> Dict[str, Any]:
        """Fetch and cache JWKS from Azure AD"""
        now = datetime.utcnow()
        
        if (self._jwks_cache and self._jwks_cache_time and 
            now - self._jwks_cache_time < self._cache_duration):
            return self._jwks_cache
            
        async with aiohttp.ClientSession() as session:
            async with session.get(self.jwks_uri) as response:
                self._jwks_cache = await response.json()
                self._jwks_cache_time = now
                return self._jwks_cache
    
    async def validate_token(self, token: str) -> Dict[str, Any]:
        """Validate Azure AD JWT token"""
        try:
            # Decode header to get kid
            unverified_header = jose_jwt.get_unverified_header(token)
            kid = unverified_header.get("kid")
            
            if not kid:
                raise ValueError("Token missing 'kid' header")
            
            # Get JWKS
            jwks = await self.get_jwks()
            
            # Find the key
            key = None
            for jwk in jwks.get("keys", []):
                if jwk.get("kid") == kid:
                    key = jwk
                    break
                    
            if not key:
                raise ValueError(f"Unable to find key with kid: {kid}")
            
            # Validate token
            payload = jose_jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=self.valid_audiences,
                issuer=self.issuer,
                options={
                    "verify_signature": True,
                    "verify_aud": True,
                    "verify_iat": True,
                    "verify_exp": True,
                    "verify_nbf": True,
                    "verify_iss": True,
                    "verify_sub": True,
                    "require_exp": True,
                    "require_iat": True,
                    "require_nbf": True,
                }
            )
            
            # Additional validation
            if "scp" not in payload and "roles" not in payload:
                raise ValueError("Token missing required scopes or roles")
                
            return payload
            
        except JWTError as e:
            logger.error(f"JWT validation error: {str(e)}")
            raise ValueError(f"Invalid token: {str(e)}")
        except Exception as e:
            logger.error(f"Token validation error: {str(e)}")
            raise

class TokenManager:
    def __init__(self):
        self.sessions: Dict[str, Dict[str, Any]] = {}
        
    def create_session(self, user_id: str, token_data: Dict[str, Any]) -> str:
        """Create a new session for authenticated user"""
        session_id = jwt.encode(
            {
                "user_id": user_id,
                "exp": datetime.utcnow() + timedelta(hours=1)
            },
            os.environ.get("SESSION_SECRET", "default-secret"),
            algorithm="HS256"
        )
        
        self.sessions[session_id] = {
            "user_id": user_id,
            "token_data": token_data,
            "created_at": datetime.utcnow()
        }
        
        return session_id
        
    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve session data"""
        return self.sessions.get(session_id)
        
    def invalidate_session(self, session_id: str):
        """Invalidate a session"""
        if session_id in self.sessions:
            del self.sessions[session_id]
            
    def cleanup_expired_sessions(self):
        """Remove expired sessions"""
        now = datetime.utcnow()
        expired = []
        
        for session_id, data in self.sessions.items():
            if now - data["created_at"] > timedelta(hours=1):
                expired.append(session_id)
                
        for session_id in expired:
            del self.sessions[session_id]