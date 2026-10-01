# JSON, not PaperTrail's default YAML: Rails 8's Psych safe-loading
# (config.active_record.use_yaml_unsafe_load defaults to false) silently
# refuses to deserialize the custom Ruby object tags (ActiveSupport::
# TimeWithZone, etc.) YAML would otherwise store, so Version#changeset
# comes back empty instead of raising. JSON has no such tags to reject.
PaperTrail.serializer = PaperTrail::Serializers::JSON
