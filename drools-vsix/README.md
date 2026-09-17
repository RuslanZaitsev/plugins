# Drools / KIE VS Code extensions (offline .vsix)

Packages pulled from the VS Code Marketplace for offline installation on a machine
without Marketplace access.

| File | Extension id | Source |
|---|---|---|
| jim-moody.drools-1.2.0.vsix | `jim-moody.drools` | github.com/jim-moody/vscode-drools |
| jhhtaylor.drools-formatter-0.3.1.vsix | `jhhtaylor.drools-formatter` | github.com/jhhtaylor/drools-formatter |
| kie-group.vscode-extension-kie-ba-bundle-10.2.0.vsix | `kie-group.vscode-extension-kie-ba-bundle` | github.com/apache/incubator-kie-tools |
| kie-group.bpmn-vscode-extension-10.2.0.vsix | dependency of the bundle | same |
| kie-group.dmn-vscode-extension-10.2.0.vsix | dependency of the bundle | same |
| kie-group.extended-services-vscode-extension-10.2.0.vsix | dependency of the bundle | same |

The KIE BA Bundle is a meta-extension: its `extensionDependencies` are the three
`kie-group.*` packages above. Offline installation does not resolve dependencies,
so install them **before** the bundle.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

or manually, in this order:

```powershell
code --install-extension .\jim-moody.drools-1.2.0.vsix
code --install-extension .\jhhtaylor.drools-formatter-0.3.1.vsix
code --install-extension .\kie-group.bpmn-vscode-extension-10.2.0.vsix
code --install-extension .\kie-group.dmn-vscode-extension-10.2.0.vsix
code --install-extension .\kie-group.extended-services-vscode-extension-10.2.0.vsix
code --install-extension .\kie-group.vscode-extension-kie-ba-bundle-10.2.0.vsix
code --list-extensions --show-versions
```

Minimum VS Code version required: 1.80.0 (drools-formatter is the strictest).

## Notes

- Files are binary; if the repo is cloned on Windows make sure git does not mangle
  them — `.gitattributes` in this repo marks `*.vsix` as binary.
- Verify integrity after transfer with `checksums.txt`:
  `Get-FileHash *.vsix -Algorithm SHA256`

- `extended-services` is a Java application bundled as jars (Vert.x + Drools/KIE runtime),
  platform-independent — it needs a JRE available on the machine.
- `kie-group.extended-services-vscode-extension-10.2.0.vsix` is ~56 MB: GitHub warns
  above 50 MB but accepts files up to 100 MB, so a plain commit works (no LFS needed).
