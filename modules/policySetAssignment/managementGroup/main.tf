# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Description: Creates a Policy Set Assignment
# Credit: gettek
##################################################
# RESOURCES                                      #
##################################################

resource "azurerm_management_group_policy_assignment" "set" {
  name                 = local.assignment_name
  display_name         = local.display_name
  description          = local.description
  metadata             = local.metadata
  parameters           = local.parameters
  management_group_id  = var.assignment_scope
  not_scopes           = var.assignment_not_scopes
  enforce              = var.assignment_enforcement_mode
  policy_definition_id = var.initiative.id
  location             = var.assignment_location

  dynamic "non_compliance_message" {
    for_each = local.non_compliance_message
    content {
      content                        = non_compliance_message.value
      policy_definition_reference_id = non_compliance_message.key == "null" ? null : non_compliance_message.key
    }
  }

  dynamic "identity" {
    for_each = local.identity_type
    content {
      type         = identity.value
      identity_ids = var.identity_ids
    }
  }

  dynamic "overrides" {
    for_each = var.overrides
    content {
      value = overrides.value.effect
      selectors {
        in     = try(overrides.value.selectors.in, null)
        not_in = try(overrides.value.selectors.not_in, null)
      }
    }
  }

  dynamic "resource_selectors" {
    for_each = var.resource_selectors
    content {
      name = try(resource_selectors.value.name, null)
      selectors {
        kind   = resource_selectors.value.selectors.kind
        in     = try(resource_selectors.value.selectors.in, null)
        not_in = try(resource_selectors.value.selectors.not_in, null)
      }
    }
  }
}

## role assignments ##
resource "azurerm_role_assignment" "rem_role" {
  for_each                         = toset(local.role_definition_ids)
  scope                            = coalesce(var.role_assignment_scope, var.assignment_scope)
  role_definition_id               = each.value
  principal_id                     = azurerm_management_group_policy_assignment.set.identity[0].principal_id
  skip_service_principal_aad_check = true
}

## remediation tasks ##
resource "azurerm_management_group_policy_remediation" "rem" {
  for_each                       = { for dr in local.definition_reference.mg : basename(dr.reference_id) => dr }
  name                           = lower("${each.key}-${formatdate("DD-MM-YYYY-hh:mm:ss", timestamp())}")
  management_group_id            = local.remediation_scope
  policy_assignment_id           = azurerm_management_group_policy_assignment.set.id
  policy_definition_reference_id = lower(each.key)
  location_filters               = var.location_filters
  failure_percentage             = var.failure_percentage
  parallel_deployments           = var.parallel_deployments
  resource_count                 = var.resource_count

  lifecycle {
    ignore_changes = [ name ]
  }

}
