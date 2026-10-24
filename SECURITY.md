# Security

MoonShim processes text and writes files requested by the caller. It does not
execute generated code, access the network, or inspect secrets.

The generated source must be reviewed before being committed to a library,
because API compatibility does not prove behavioral equivalence.

To report a parser denial-of-service, path traversal, or code-generation safety
issue, open a private security advisory in the repository.
