# Scripts

- `validate.sh` runs the local Steward validation gate for shell syntax,
  workflow-branch policy, whitespace, and the targeted ixwebsocket build check
  when a build tree exists.
- `validate-workflow-contract.sh` checks that CodeQL pull-request analysis and
  catalog-manifest push validation cover this fork's `release` integration
  branch.
