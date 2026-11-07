# NairaFlow infrastructure guardrails. Checked against `tofu show -json` plan output.
package main

import rego.v1

# Resources that will exist after this change (creates, updates, no-ops).
changed contains rc if {
	some rc in input.resource_changes
	rc.change.after != null
}

# 1. Repos must be private (stops another "public KYC bucket").
deny contains msg if {
	some rc in changed
	rc.type == "gitlab_project"
	rc.change.after.visibility_level != "private"
	msg := sprintf("%s must be private (found %v)", [rc.address, rc.change.after.visibility_level])
}

# 2. Repos must block merges when the pipeline fails.
deny contains msg if {
	some rc in changed
	rc.type == "gitlab_project"
	rc.change.after.only_allow_merge_if_pipeline_succeeds != true
	msg := sprintf("%s must only allow merges when the pipeline succeeds", [rc.address])
}

# 3. Every namespace needs owner, cost-centre and env labels.
required_labels := {"owner", "cost-centre", "env"}

deny contains msg if {
	some rc in changed
	rc.type == "kubernetes_namespace_v1"
	labels := object.get(rc.change.after.metadata[0], "labels", {})
	present := {k | some k, _ in labels}
	missing := required_labels - present
	count(missing) > 0
	msg := sprintf("%s is missing labels %v", [rc.address, missing])
}

# 4. Production namespaces must have a resource quota.
deny contains msg if {
	some rc in changed
	rc.type == "kubernetes_namespace_v1"
	rc.change.after.metadata[0].labels.env == "prod"
	not has_quota(object.get(rc, "module_address", ""))
	msg := sprintf("%s is a prod namespace without a resource quota", [rc.address])
}

has_quota(mod) if {
	some q in changed
	q.type == "kubernetes_resource_quota_v1"
	object.get(q, "module_address", "") == mod
}

# 5. Never open admin ports to the whole internet.
admin_ports := {"22", "3389", "5432"}

deny contains msg if {
	some rc in changed
	rc.type == "kubernetes_network_policy_v1"
	some rule in rc.change.after.spec[0].ingress
	some src in rule.from
	some block in src.ip_block
	block.cidr == "0.0.0.0/0"
	some p in rule.ports
	p.port in admin_ports
	msg := sprintf("%s opens port %v to 0.0.0.0/0", [rc.address, p.port])
}
