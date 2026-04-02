#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Profile definition for harbor_srv root image build.
# Used by scripts/build-image.sh for file_permissions.

file_permissions=(
  ["/"]="0:0:755"
  ["/etc/passwd"]="0:0:644"
  ["/etc/shadow"]="0:0:400"
  ["/etc/group"]="0:0:644"
  ["/root"]="0:0:700"
  ["/root/.ssh"]="0:0:700"
  ["/root/.ssh/authorized_keys"]="0:0:600"
  ["/usr/local/bin/harbor-compose-up.sh"]="0:0:750"
  ["/usr/local/bin/harbor-compose-down.sh"]="0:0:750"
  ["/usr/local/bin/harbor-compose-update.sh"]="0:0:750"
  ["/usr/local/sbin/harbor-deploy.sh"]="0:0:750"
  ["/usr/local/sbin/harbor-compose-ctl.sh"]="0:0:750"
  ["/etc/harbor-runner"]="0:0:755"
  ["/etc/harbor-runner/compose.yaml"]="0:0:644"
  ["/etc/sudoers.d/gh-deploy"]="0:0:440"
  ["/var/lib/gh-deploy"]="967:967:700"
  ["/var/lib/gh-deploy/.ssh"]="967:967:700"
  ["/var/lib/gh-deploy/.ssh/authorized_keys"]="967:967:600"
  ["/var/lib/compose-deploy"]="966:966:700"
  ["/var/lib/compose-deploy/.ssh"]="966:966:700"
  ["/var/lib/compose-deploy/.ssh/authorized_keys"]="966:966:600"
  ["/var/lib/krb5kdc"]="0:0:700"
)


