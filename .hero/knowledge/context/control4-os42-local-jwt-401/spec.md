---
title: Control4 OS 4.2 local JWT 401
slug: control4-os42-local-jwt-401
type: context
status: active
domain: engineering
created: 2026-08-21
tags: [control4, auth]
relates-to:
  - control4-focused-room-remote
  - director-session
---
# Control4 OS 4.2 local JWT 401

## Overview

V1 of this plugin targets Control4 OS 3.x local REST with a cloud-issued director bearer JWT (the pyControl4 account → director token path). OS 4.2 currently rejects that token on local `/api/v1/*`.

## Details

On OS 4.2, `get_director_bearer_token` can succeed while `GET https://<controller>/api/v1/items` returns 401. The JWT's `Realm` is `remote.control4.com:5080`, which does not match a direct connection to the controller IP. This is a documented community incompatibility, not a child of `control4-focused-room-remote`. Do not jailbreak. Surface a clear 401 in the plugin; do not treat OS 4.2 as a silent support-matrix row.

## References

- https://github.com/lawtancool/pyControl4/issues/66
- https://lawtancool.github.io/pyControl4/director.html
