---
author: Nathan Anderson
date: MMMM dd, YYYY
paging: Slide %d / %d
---

# Steps to Publish

1. Initialize Library
2. Write Library
4. Write some tests
5. Publish!

---

# 1. Initialize Your Library!

---

## Publishing Requirements

- You must include a LICENSE file.
- Your package must be smaller than 100 MB after gzip compression.
- Your package should depend only on hosted dependencies (from the default pub
package server) and SDK dependencies (sdk: flutter).
- You must have a Google Account,

---

## Publishing is Forever

To make sure projects don't break after using a dependency, you are unable to
take down a published project.

If you will have regrets publishing, turn back now.

---

## Initialize Project

Creating a flutter library is straightforward, simply run the command

```sh
flutter create -template=package <package_name>
```

Creates a new flutter project with a simple example library inside.

---

## Select License

This is important. The dart team recommends the BSD-3 clause license.

---

## pubspec.yaml Considerations

In the `pubspec.yaml` file, it is recommended to include a "homepage" or "repository"
field. This gets popultated into the package page on [pub.dev](https://pub.dev).

```yaml
# Top of pubspec.yaml file
name: stripe_native_card_field
description: A native flutter implementation of Stripes Card Field.
version: 0.0.1
repository: https://git.fosscat.com/nathananderson98/stripe_native_card_field
```

---

# 2. Write Your Library

---

## Important Bits

Be sure to include a `README.md` file at the root of your library as this is
what determines the content of your packages page on [pub.dev](https://pub.dev)

A `CHANGELOG.md` file can also be included and will fill out a tab on the
package's page

### Verified Publisher

You can publish under a verified domain as a "Verified Publisher". Its a bit of
a process. But it adds a cool checkmark on your package and you can hide your email.

---

## Tests

Its a good idea to include some Unit Tests and Widget Tests for your library.

---

# 3. Publishing!

---

## Dry Run

To see the results of what publishing will look like without going through with it run

```sh
dart pub publish --dry-run
```

## Helpful Links

[Dart Publishing Guide](https://dart.dev/tools/pub/publishing)
