# Midterm Practice -- Notes

## Task 5: git hygiene

Deleting the file and the credential in a new commit does not remove them from earlier commits, so anyone with the repo can still recover them from git history; the credential must be treated as compromised and rotated, and the history rewritten if the secret has to be purged.
