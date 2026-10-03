from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AppointmentReminder, Notification
from .serializers import (
    AppointmentReminderSerializer,
    NotificationSerializer,
)


class NotificationListView(generics.ListAPIView):
    """
    Return notifications belonging to the authenticated user.
    """

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Notification.objects.filter(
            user=self.request.user,
        ).select_related(
            "appointment",
        )

        unread_value = self.request.query_params.get(
            "unread",
            "",
        )

        if unread_value.strip().lower() == "true":
            queryset = queryset.filter(
                is_read=False,
            )

        return queryset.order_by(
            "-created_at",
        )


class AppointmentReminderListView(
    generics.ListAPIView,
):
    """
    Return appointment reminders belonging to the patient.
    """

    serializer_class = AppointmentReminderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return AppointmentReminder.objects.filter(
            appointment__patient=self.request.user,
        ).select_related(
            "appointment",
            "appointment__patient",
            "appointment__doctor_clinic",
            "appointment__doctor_clinic__doctor",
            "appointment__doctor_clinic__doctor__user",
            "appointment__doctor_clinic__clinic",
        ).order_by(
            "scheduled_for",
        )


class NotificationUnreadCountView(APIView):
    """
    Return the authenticated user's unread notification count.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        unread_count = Notification.objects.filter(
            user=request.user,
            is_read=False,
        ).count()

        return Response(
            {
                "unread_count": unread_count,
            },
            status=status.HTTP_200_OK,
        )


class NotificationMarkReadView(APIView):
    """
    Mark one notification belonging to the user as read.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(
            Notification,
            pk=pk,
            user=request.user,
        )

        if not notification.is_read:
            notification.is_read = True
            notification.read_at = timezone.now()

            notification.save(
                update_fields=[
                    "is_read",
                    "read_at",
                ],
            )

        serializer = NotificationSerializer(
            notification,
            context={
                "request": request,
            },
        )

        return Response(
            {
                "message": "Notification marked as read.",
                "notification": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


class NotificationMarkAllReadView(APIView):
    """
    Mark all unread notifications belonging to the user as read.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        updated_count = Notification.objects.filter(
            user=request.user,
            is_read=False,
        ).update(
            is_read=True,
            read_at=timezone.now(),
        )

        return Response(
            {
                "message": (
                    "All notifications marked as read."
                ),
                "updated_count": updated_count,
            },
            status=status.HTTP_200_OK,
        )