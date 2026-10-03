from rest_framework.permissions import BasePermission

from accounts.models import UserProfile


def get_user_role(user):
    """
    Authenticated user ka role database se return karega.

    Database query use karne se cached ya outdated profile role ka
    problem nahi aayega.
    """

    if not user or not user.is_authenticated:
        return None

    # Administrator ko separate admin role dein.
    if user.is_superuser:
        return "admin"

    role = (
        UserProfile.objects
        .filter(user=user)
        .values_list("role", flat=True)
        .first()
    )

    # Role comparison ko case-insensitive banayein.
    if role:
        return str(role).strip().lower()

    return None


class IsPatient(BasePermission):
    """
    Sirf patient role ko endpoint access karne dega.
    """

    message = "Only patients can perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == "patient"


class IsDoctor(BasePermission):
    """
    Sirf doctor role ko endpoint access karne dega.
    """

    message = "Only doctors can perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == "doctor"


class IsDoctorOrPatient(BasePermission):
    """
    Doctor aur patient dono endpoint access kar sakte hain.
    """

    message = "Only doctors or patients can access this endpoint."

    def has_permission(self, request, view):
        role = get_user_role(request.user)

        return role in [
            "doctor",
            "patient",
        ]


class IsAdminUser(BasePermission):
    """
    Sirf Django administrator ko endpoint access karne dega.
    """

    message = "Only administrators can perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_superuser
        )