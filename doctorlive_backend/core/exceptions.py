from rest_framework.views import exception_handler


def doctorlive_exception_handler(exc, context):
    """
    Return all API errors in a consistent DoctorLive format.
    """

    response = exception_handler(exc, context)

    if response is None:
        return None

    original_data = response.data

    if isinstance(original_data, dict):
        message = original_data.get(
            "detail",
            "Request could not be completed.",
        )
    else:
        message = "Request could not be completed."

    response.data = {
        "success": False,
        "status_code": response.status_code,
        "message": message,
        "errors": original_data,
    }

    return response