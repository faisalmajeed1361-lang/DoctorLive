from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Appointment, DoctorAvailabilitySlot


@receiver(post_save, sender=Appointment)
def release_cancelled_appointment_slot(
    sender,
    instance,
    **kwargs,
):
    """
    Appointment cancel hone par booked slot automatically release karega.
    """

    if instance.status != "cancelled":
        return

    DoctorAvailabilitySlot.objects.filter(
        appointment=instance
    ).update(
        appointment=None
    )