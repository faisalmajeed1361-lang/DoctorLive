from django.contrib import admin

from .models import UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    """
    Admin panel mein Patient, Doctor aur Receptionist profiles
    ko manage karne ke options.
    """

    # Profile list mein ye columns nazar aayenge
    list_display = (
        "id",
        "username",
        "role",
        "phone_number",
        "city",
        "created_at",
    )

    # Right side par role aur city filters
    list_filter = (
        "role",
        "city",
        "created_at",
    )

    # Username, email, phone aur city se search
    search_fields = (
        "user__username",
        "user__email",
        "phone_number",
        "city",
    )

    # User selection dropdown ko searchable banata hai
    autocomplete_fields = ("user",)

    # Newest profile pehle show hogi
    ordering = ("-created_at",)

    @admin.display(description="Username")
    def username(self, obj):
        return obj.user.username