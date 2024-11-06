locals {
  create_url_lists = { for k, v in var.policy_rules.url_lists : v.url_list => v if v.values != null }
}

locals {
  swp_tag_value = google_tags_tag_value.swp.id
}

# Create a tag key
resource "google_tags_tag_key" "swp_tag_key" {
  parent      = "projects/${var.project_id}"
  short_name  = "internet"
  description = "Allow internet access"
  purpose     = "GCE_FIREWALL"
  purpose_data = {
  network = "${var.project_id}/${var.network}"
}
  }


# Create tag values associated with the key
resource "google_tags_tag_value" "swp" {
  parent      = google_tags_tag_key.swp_tag_key.id
  short_name  = "internet-access"
  description = "Allow internet access"
}

resource "google_network_security_gateway_security_policy" "policy" {
  provider              = google-beta
  project               = var.project_id
  name                  = var.name
  location              = var.region
  description           = var.description
  tls_inspection_policy = var.tls_inspection_config != null ? google_network_security_tls_inspection_policy.tls-policy[0].id : null
}

resource "google_network_security_tls_inspection_policy" "tls-policy" {
  count                 = var.tls_inspection_config != null ? 1 : 0
  provider              = google-beta
  project               = var.project_id
  name                  = var.name
  location              = var.region
  description           = coalesce(var.tls_inspection_config.description, var.description)
  ca_pool               = var.tls_inspection_config.ca_pool
  exclude_public_ca_set = var.tls_inspection_config.exclude_public_ca_set
}

resource "google_network_security_gateway_security_policy_rule" "secure_tag_rules" {
  for_each                = var.policy_rules.secure_tags
  provider                = google-beta
  project                 = var.project_id
  name                    = each.key
  location                = var.region
  description             = coalesce(each.value.description, var.description)
  gateway_security_policy = google_network_security_gateway_security_policy.policy.name
  enabled                 = each.value.enabled
  priority                = each.value.priority
  session_matcher = trimspace(<<-EOT
  source.matchTag('${each.value.tag}')%{if each.value.session_matcher != null} && (${each.value.session_matcher})%{endif~}
  EOT
  )
  application_matcher    = each.value.application_matcher
  tls_inspection_enabled = each.value.tls_inspection_enabled
  basic_profile          = each.value.action
}

resource "google_network_security_url_lists" "url_lists" {
  for_each    = local.create_url_lists
  provider    = google-beta
  project     = var.project_id
  name        = each.key
  location    = var.region
  description = coalesce(each.value.description, var.description)
  values      = each.value.values
}
resource "google_network_security_gateway_security_policy_rule" "url_list_rules" {
  for_each                = var.policy_rules.url_lists
  provider                = google-beta
  project                 = var.project_id
  name                    = each.key
  location                = var.region
  description             = coalesce(each.value.description, var.description)
  gateway_security_policy = google_network_security_gateway_security_policy.policy.name
  enabled                 = each.value.enabled
  priority                = each.value.priority
  session_matcher = join(" && ", [
    trimspace(<<-EOT
    inUrlList(host(), '%{~if each.value.values != null~}
    ${~google_network_security_url_lists.url_lists[each.value.url_list].id~}
    %{~else~}
    ${~each.value.url_list~}
    %{~endif~}') 
  EOT
    ),
    "destination.port == ${each.value.port}",
    "source.matchTag('${local.swp_tag_value}')"
   // "source.matchTag('tagValues/281484695999578')"
  ])
 
  application_matcher    = each.value.application_matcher
  tls_inspection_enabled = each.value.tls_inspection_enabled
  basic_profile          = each.value.action
}
# resource "google_network_security_gateway_security_policy_rule" "url_list_rules" {
#   for_each                = var.url_lists
#   provider                = google-beta
#   project                 = var.project_id
#   name                    = replace(each.key, "/[^a-z0-9-]/", "") # Ensures valid resource name
#   location                = var.region
#   description             = lookup(each.value, "description", "Default description")
#   gateway_security_policy = google_network_security_gateway_security_policy.policy.name
#   enabled                 = lookup(each.value, "enabled", true)
#   priority                = each.value.priority

#   # Apply the dynamically constructed session_matcher
#   session_matcher         = local.session_matchers[each.key]

#   application_matcher     = lookup(each.value, "application_matcher", null)
#   tls_inspection_enabled  = lookup(each.value, "tls_inspection_enabled", false)
#   basic_profile           = lookup(each.value, "action", "ALLOW")
# }

resource "google_network_security_gateway_security_policy_rule" "custom_rules" {
  for_each                = var.policy_rules.custom
  project                 = var.project_id
  provider                = google-beta
  name                    = each.key
  location                = var.region
  description             = coalesce(each.value.description, var.description)
  gateway_security_policy = google_network_security_gateway_security_policy.policy.name
  enabled                 = each.value.enabled
  priority                = each.value.priority
  session_matcher         = each.value.session_matcher
  application_matcher     = each.value.application_matcher
  tls_inspection_enabled  = each.value.tls_inspection_enabled
  basic_profile           = each.value.action
}

resource "google_network_services_gateway" "gateway" {
  provider                             = google-beta
  project                              = var.project_id
  name                                 = var.name
  location                             = var.region
  description                          = var.description
  labels                               = var.labels
  addresses                            = var.addresses != null ? var.addresses : []
  type                                 = "SECURE_WEB_GATEWAY"
  ports                                = var.ports
  scope                                = var.scope != null ? var.scope : ""
  //certificate_urls                     = var.certificates
  gateway_security_policy              = google_network_security_gateway_security_policy.policy.id
  network                              = var.network
  subnetwork                           = var.subnetwork
  delete_swg_autogen_router_on_destroy = var.delete_swg_autogen_router_on_destroy
}
 
