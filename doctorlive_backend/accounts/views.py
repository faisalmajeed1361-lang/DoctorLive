from django.contrib.auth import authenticate

from rest_framework import parsers, permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import UserProfile
from .serializers import (
    ProfileSerializer,
    RegisterSerializer,
)


def get_user_role(user):
    """
    Return the effective DoctorLive application role.

    Priority:
    1. Superuser or staff account
    2. DoctorProfile relationship
    3. UserProfile doctor role
    4. Patient fallback
    """

    if user.is_superuser or user.is_staff:
        return "admin"

    # A complete doctor account normally has a DoctorProfile.
    if hasattr(user, "doctor_profile"):
        return "doctor"

    # Some existing or test doctor accounts may only have
    # their doctor role stored inside UserProfile.
    profile_role = UserProfile.objects.filter(
        user=user,
    ).values_list(
        "role",
        flat=True,
    ).first()

    if profile_role == UserProfile.Role.DOCTOR:
        return "doctor"

    return "patient"


def get_profile_data(user, request):
    """
    Return serialized profile data with the effective role and
    Django permission flags.
    """

    profile_data = dict(
        ProfileSerializer(
            user,
            context={
                "request": request,
            },
        ).data
    )

    profile_data["role"] = get_user_role(
        user,
    )

    profile_data["is_staff"] = user.is_staff
    profile_data["is_superuser"] = user.is_superuser

    return profile_data


class RegisterView(APIView):
    """
    Register a new patient account.

    Public registration always creates a patient account.
    Doctor and admin accounts are managed from the backend.
    """

    permission_classes = [
        permissions.AllowAny,
    ]

    def post(self, request):
        serializer = RegisterSerializer(
            data=request.data,
        )

        serializer.is_valid(
            raise_exception=True,
        )

        user = serializer.save()

        token, _ = Token.objects.get_or_create(
            user=user,
        )

        return Response(
            {
                "message": (
                    "Patient account created successfully."
                ),
                "token": token.key,
                "role": "patient",
                "user": get_profile_data(
                    user,
                    request,
                ),
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    """
    Authenticate credentials and return the user's token,
    role and profile.
    """

    permission_classes = [
        permissions.AllowAny,
    ]

    def post(self, request):
        username = str(
            request.data.get(
                "username",
                "",
            )
        ).strip()

        password = str(
            request.data.get(
                "password",
                "",
            )
        )

        if not username or not password:
            return Response(
                {
                    "error": (
                        "Username and password are required."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = authenticate(
            request=request,
            username=username,
            password=password,
        )

        if user is None:
            return Response(
                {
                    "error": (
                        "Invalid username or password."
                    )
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {
                    "error": (
                        "This account is inactive."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        token, _ = Token.objects.get_or_create(
            user=user,
        )

        role = get_user_role(
            user,
        )

        profile_data = get_profile_data(
            user,
            request,
        )

        return Response(
            {
                "message": "Login successful.",
                "token": token.key,
                "role": role,
                "user": profile_data,
            },
            status=status.HTTP_200_OK,
        )


class ProfileView(APIView):
    """
    Handle GET, PATCH and PUT operations for the current user.
    """

    permission_classes = [
        permissions.IsAuthenticated,
    ]

    parser_classes = [
        parsers.JSONParser,
        parsers.FormParser,
        parsers.MultiPartParser,
    ]

    def get(self, request):
        """
        Return the current authenticated user's profile.
        """

        profile_data = get_profile_data(
            request.user,
            request,
        )

        return Response(
            profile_data,
            status=status.HTTP_200_OK,
        )

    def patch(self, request):
        """
        Partially update the current user's profile.
        """

        serializer = ProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={
                "request": request,
            },
        )

        serializer.is_valid(
            raise_exception=True,
        )

        updated_user = serializer.save()

        role = get_user_role(
            updated_user,
        )

        return Response(
            {
                "message": (
                    "Profile updated successfully."
                ),
                "role": role,
                "user": get_profile_data(
                    updated_user,
                    request,
                ),
            },
            status=status.HTTP_200_OK,
        )

    def put(self, request):
        """
        Safely handle PUT as a partial profile update.
        """

        return self.patch(
            request,
        )


class LogoutView(APIView):
    """
    Delete the current authentication token.
    """

    permission_classes = [
        permissions.IsAuthenticated,
    ]

    def post(self, request):
        if request.auth:
            request.auth.delete()

        return Response(
            {
                "message": "Logout successful.",
            },
            status=status.HTTP_200_OK,
        )