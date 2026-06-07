# StillPoint Release Keys

This folder is the portable signing location for building StillPoint release APKs
and Android App Bundles from more than one machine.

The Gradle release build checks for signing files in this order:

1. `android/key.properties`
2. `keys/key.properties`

Use the top-level `keys/` folder when you want the signing setup to sync through
your private cloud or private repository. The folder is intentionally not ignored
by this project.

## Required files

For a private-cloud or private-repository workflow, this folder should contain
the real release signing files:

```text
keys/
  key.properties
  upload-keystore.jks
```

Before building on a second machine, check that the cloud/private-repo sync has
finished and that both files are present there too. The required properties file
is named `key.properties`, not `keys.properties`. Do not leave these files on a
public remote; make the remote private immediately if the files are synced
through Git.

Create or recreate `key.properties` from `key.properties.example`.

```properties
storeFile=upload-keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
```

When `key.properties` is inside this folder, `storeFile` is resolved relative to
this folder unless you provide an absolute path. The release key alias is
`upload`.

## Handling later

Treat this folder as sensitive. Keep it in a private cloud/private repository so
release builds work on your other machine after a clone. Before a public release
process or team handoff, move the raw keystore and passwords into a password
manager, encrypted vault, or CI secret store and keep only templates in the
repository.
