# Ansible parameters (most important)

* `wsid_rotation_minutes` -- by default is 10. For demo purposes it's recommended to set up 3 (but not smaller to avoid various race conditions and collisions).
* `wsid_identities` - an array, default value is `["_"]` which corresponds to single placeholder identity named `_`. It's recommended to set up something more semantically meaningful
* `wsid_disabled_identities` -- an array of identifiers, empty by default. Used to clean up artifacts of previously configured identifiers.
* `wsid_delay_before_update_seconds` -- time between publication of updated hashes/pubkeys and invocation of hooks which deploy private secrets into consumers. By default is 30, you can keep this value, it corresponds with caching settings on the basic authenticator side.

