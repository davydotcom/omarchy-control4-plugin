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

V1 of this plugin talks to the Director over LAN with a cloud-issued director bearer JWT (the pyControl4 account → director token path). That path **works on Control4 OS 4** (this repo's development house) and on OS 3.x.

**OS 4.2** is a separate incompatibility: some controllers (reported: OS 4.2.0.753182-res) still reject that token on local `/api/v1/*` with HTTP 401. Do not treat a working local JWT as proof the house is OS 3.x. Do not jailbreak. Surface a clear 401; do not silently skip OS 4.2 as if OS 4 as a whole were unsupported.

## Details

On OS 4.2, `get_director_bearer_token` can succeed while `GET https://<controller>/api/v1/items` returns 401. The JWT's `Realm` is `remote.control4.com:5080`, which does not match a direct connection to the controller IP. This is a documented community incompatibility, not a child of `control4-focused-room-remote`. Do not jailbreak. Surface a clear 401 in the plugin; do not treat OS 4.2 as a silent support-matrix row.

## References

- https://github.com/lawtancool/pyControl4/issues/66
- https://lawtancool.github.io/pyControl4/director.html
