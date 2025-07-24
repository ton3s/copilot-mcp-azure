import azure.functions as func
import logging

app = func.FunctionApp()

@app.function_name(name="test")
@app.route(route="test", methods=["GET"], auth_level=func.AuthLevel.ANONYMOUS)
def test_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Functions are working!", status_code=200)