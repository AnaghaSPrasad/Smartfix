from django.db import models


class Service(models.Model):
    name = models.CharField(max_length=100)
    category = models.CharField(max_length=50)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=8, decimal_places=2)
    image = models.URLField(blank=True, null=True)
    rating = models.DecimalField(max_digits=2, decimal_places=1, blank=True, null=True)

    def __str__(self):
        return self.name
