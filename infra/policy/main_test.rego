package main

import rego.v1

rc(type, after) := {"address": sprintf("%s.x", [type]), "type": type, "change": {"after": after}}

good_repo := {"visibility_level": "private", "only_allow_merge_if_pipeline_succeeds": true}

test_private_repo_allowed if {
	count(deny) == 0 with input as {"resource_changes": [rc("gitlab_project", good_repo)]}
}

test_public_repo_denied if {
	r := object.union(good_repo, {"visibility_level": "public"})
	count(deny) > 0 with input as {"resource_changes": [rc("gitlab_project", r)]}
}

test_repo_without_pipeline_gate_denied if {
	r := object.union(good_repo, {"only_allow_merge_if_pipeline_succeeds": false})
	count(deny) > 0 with input as {"resource_changes": [rc("gitlab_project", r)]}
}

ns(labels) := rc("kubernetes_namespace_v1", {"metadata": [{"name": "n", "labels": labels}]})

test_labelled_dev_namespace_allowed if {
	count(deny) == 0 with input as {"resource_changes": [ns({"owner": "a", "cost-centre": "b", "env": "dev"})]}
}

test_namespace_missing_labels_denied if {
	count(deny) > 0 with input as {"resource_changes": [ns({"env": "dev"})]}
}

test_prod_without_quota_denied if {
	count(deny) > 0 with input as {"resource_changes": [ns({"owner": "a", "cost-centre": "b", "env": "prod"})]}
}

test_prod_with_quota_allowed if {
	n := object.union(ns({"owner": "a", "cost-centre": "b", "env": "prod"}), {"module_address": "module.ns"})
	q := object.union(rc("kubernetes_resource_quota_v1", {"spec": []}), {"module_address": "module.ns"})
	count(deny) == 0 with input as {"resource_changes": [n, q]}
}

netpol(cidr, port) := rc("kubernetes_network_policy_v1", {"spec": [{"ingress": [{"from": [{"ip_block": [{"cidr": cidr}]}], "ports": [{"port": port}]}]}]})

test_open_postgres_denied if {
	count(deny) > 0 with input as {"resource_changes": [netpol("0.0.0.0/0", "5432")]}
}

test_office_range_allowed if {
	count(deny) == 0 with input as {"resource_changes": [netpol("10.20.0.0/16", "5432")]}
}
