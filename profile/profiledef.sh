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
  ["/usr/local/bin/harbor-runner-bootstrap"]="0:0:755"
  ["/usr/local/bin/harbor-compose-up"]="0:0:755"
  ["/usr/local/bin/harbor-compose-down"]="0:0:755"
  ["/usr/local/bin/harbor-compose-update"]="0:0:755"
  ["/usr/local/sbin/harbor-deploy"]="0:0:755"
  ["/usr/local/sbin/harbor-compose-ctl"]="0:0:755"
  ["/etc/sudoers.d/runner"]="0:0:440"
  ["/var/lib/runner"]="968:968:700"
)

