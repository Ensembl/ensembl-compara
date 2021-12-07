## Description

_Describe the problem you're addressing here._

**Related JIRA tickets:**
- ENSCOMPARASW-XXXX

## Overview of changes
_Give details of what changes were required to solve the problem. Break into sections if applicable._

#### Change 1
- _detail 1.1_

#### Change 2
- _detail 2.1_

## Testing
_How was this tested? Have new unit tests been included?_

## Notes
_Optional extra information._

---

## PR review checklist

- Is the PR against an appropriate branch?
- Does the code adhere to coding guidelines?
- Does the code do what it claims to do?
- Is the code readable?
  Is it appropriately documented?
- Is the logic in the correct place?
- Was the code tested appropriately?
  Are there unit tests?
  Are unit tests self-contained and non-redundant?
- Did Travis CI pass for the code in the PR?
  Is Codecov acceptable based on the included/updated unit tests?
- Will the new code fail gracefully?
- Does the code follow good practice for writing performant code
  (e.g. using a database transaction rather than repeated queries outside of a transaction)?
- Does it bring in an unnecessary dependency?
- If you are reviewing a new analysis, is it future-proof and pluggable?
- Does the PR meet agile guidelines?
