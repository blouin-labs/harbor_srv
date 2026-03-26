<!-- vale Microsoft.Headings = NO -->
# CLAUDE.md
<!-- vale Microsoft.Headings = YES -->

Don't edit this file. The actual instructions for this repository live privately in `blouin-labs/claude`.

At the start of every session, run the following commands and read their output before proceeding with any work:

```bash
gh api repos/blouin-labs/claude/contents/CLAUDE.md --jq '.content' | base64 -d
gh api repos/blouin-labs/claude/contents/harbor_srv/CLAUDE.md --jq '.content' | base64 -d
```

## Issues

Issues for this repository live in **[blouin-labs/issues](https://github.com/blouin-labs/issues)**. Apply the `harbor_srv` label to issues related to this repository. Repository-specific labels also include `golden image`.
