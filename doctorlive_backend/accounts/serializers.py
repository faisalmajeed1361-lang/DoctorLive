from django.contrib.auth import get_user_model
from django.db import transaction

from rest_framework import serializers

from doctors.models import DoctorProfile

from .models import UserProfile


User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    """
    Create a patient user and profile through public registration.
    """

    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={"input_type": "password"},
    )

    phone_number = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    city = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    address = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = User

        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "password",
            "phone_number",
            "city",
            "address",
        )

        read_only_fields = (
            "id",
        )

    def validate_email(self, value):
        """
        Prevent duplicate email addresses.
        """
        normalized_email = value.strip().lower()

        if (
            normalized_email
            and User.objects.filter(
                email__iexact=normalized_email,
            ).exists()
        ):
            raise serializers.ValidationError(
                "An account with this email already exists."
            )

        return normalized_email

    @transaction.atomic
    def create(self, validated_data):
        """
        Create the user and patient profile in one transaction.
        """
        phone_number = validated_data.pop(
            "phone_number",
            "",
        )

        city = validated_data.pop(
            "city",
            "",
        )

        address = validated_data.pop(
            "address",
            "",
        )

        password = validated_data.pop(
            "password",
        )

        user = User.objects.create_user(
            password=password,
            **validated_data,
        )

        # A signal may already have created the profile.
        UserProfile.objects.update_or_create(
            user=user,
            defaults={
                "role": UserProfile.Role.PATIENT,
                "phone_number": phone_number,
                "city": city,
                "address": address,
            },
        )

        return user


class ProfileSerializer(serializers.ModelSerializer):
    """
    Read and update the authenticated user's profile.
    """

    role = serializers.SerializerMethodField()

    phone_number = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )

    city = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )

    address = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )

    profile_image = serializers.ImageField(
        required=False,
        allow_null=True,
        write_only=True,
    )

    profile_image_url = serializers.SerializerMethodField()

    qualification = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )

    class Meta:
        model = User

        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "role",
            "phone_number",
            "city",
            "address",
            "profile_image",
            "profile_image_url",
            "qualification",
        )

        read_only_fields = (
            "id",
            "username",
            "role",
            "profile_image_url",
        )

    def _profile(self, user):
        """
        Return the user profile and safely create it when missing.
        """
        profile, _ = UserProfile.objects.get_or_create(
            user=user,
            defaults={
                "role": UserProfile.Role.PATIENT,
            },
        )

        return profile

    def get_role(self, obj):
        """
        Return the effective application role.

        A DoctorProfile takes priority over an outdated UserProfile
        role so existing doctor accounts are recognized correctly.
        """
        if obj.is_superuser or obj.is_staff:
            return "admin"

        if DoctorProfile.objects.filter(
            user=obj,
        ).exists():
            return UserProfile.Role.DOCTOR

        return self._profile(obj).role

    def get_profile_image_url(self, obj):
        """
        Return an absolute profile image URL when available.
        """
        profile = self._profile(obj)

        if not profile.profile_image:
            return None

        request = self.context.get(
            "request",
        )

        image_url = profile.profile_image.url

        if request:
            return request.build_absolute_uri(
                image_url,
            )

        return image_url

    def to_representation(self, instance):
        """
        Combine User, UserProfile and DoctorProfile information.
        """
        data = super().to_representation(
            instance,
        )

        profile = self._profile(
            instance,
        )

        data["phone_number"] = profile.phone_number
        data["city"] = profile.city
        data["address"] = profile.address

        doctor_profile = DoctorProfile.objects.filter(
            user=instance,
        ).first()

        data["qualification"] = (
            doctor_profile.qualification
            if doctor_profile
            else ""
        )

        return data

    @transaction.atomic
    def update(self, instance, validated_data):
        """
        Update User, UserProfile and doctor qualification.
        """
        profile = self._profile(
            instance,
        )

        qualification = validated_data.pop(
            "qualification",
            None,
        )

        for field in (
            "email",
            "first_name",
            "last_name",
        ):
            if field in validated_data:
                setattr(
                    instance,
                    field,
                    validated_data.pop(field),
                )

        for field in (
            "phone_number",
            "city",
            "address",
            "profile_image",
        ):
            if field in validated_data:
                setattr(
                    profile,
                    field,
                    validated_data.pop(field),
                )

        if instance.email:
            instance.email = instance.email.strip().lower()

        instance.save()
        profile.save()

        if qualification is not None:
            doctor_profile = DoctorProfile.objects.filter(
                user=instance,
            ).first()

            if doctor_profile:
                doctor_profile.qualification = (
                    qualification.strip()
                )

                doctor_profile.save(
                    update_fields=[
                        "qualification",
                    ],
                )

        return instance