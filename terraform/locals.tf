locals {
  zones           = compact(split(",", var.availability_zones != "" ? var.availability_zones : ""))
  formatted_zones = formatlist("${var.region}-%s", local.zones)
}
