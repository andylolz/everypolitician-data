require_relative 'csv'

module Source
  class Membership < CSV
    def raw_table
      super.each do |r|
        # if the source has no ID, generate one
        r[:id] = r[:name].downcase.gsub(/\s+/, '_') if r[:id].to_s.empty?

        # remap any group_id fields to our local UUID for them
        # For now we silently ignore any that are not mapped.
        r[:group_id] = partymapping.fetch(r[:group_id], r[:group_id])
      end
    end

    # Currently we just recognise a hash of k:v pairs to accept if matching
    # TODO: add 'reject' and more complex expressions
    def as_table
      return raw_table unless i(:filter)
      filter = ->(row) { i(:filter)[:accept].all? { |k, v| row[k] == v } }
      @_filtered ||= raw_table.select { |row| filter.call(row) }
    end

    # TODO: split this up. This version was migrated directly from the
    # original Rakefile approach, so is still doing too many things.
    def merged_with(csv)
      id_map = mapfile.mapping

      if merge_instructions
        reconciler = Reconciler.new(merge_instructions, ENV['GENERATE_RECONCILIATION_INTERFACE'], csv, as_table)
        raise "Can't reconcile memberships with a Reconciliation file yet" unless reconciler.filename

        pr = reconciler.reconciliation_data rescue abort($ERROR_INFO.to_s)
        pr.each { |r| id_map[r[:id]] = r[:uuid] }
      else
        # potentially reuse any IDs we already have from other sources
        csv.each { |r| id_map[r[:id]] &&= r[:uuid] } unless i(:reuse_ids) == false
      end

      # Generate UUIDs for any people we don't already know
      (as_table.map { |r| r[:id] }.uniq - id_map.keys).each do |missing_id|
        id_map[missing_id] = SecureRandom.uuid
        warn '%s -> %s' % [missing_id, id_map[missing_id]]
      end
      write_id_map_file!(id_map)

      as_table.each do |row|
        # We assume that incoming data has no useful uuid column
        row[:uuid] = id_map[row[:id]]
        csv << row.to_hash
      end

      csv
    end

    def mapfile
      @map ||= UuidMapFile.new(id_map_file)
    end

    def group_mapfile
      @gmap ||= UuidMapFile.new(group_id_map_file)
    end

    private

    def write_id_map_file!(id_map)
      mapfile.rewrite(id_map)
    end

    def id_map_file
      filename.parent.parent + 'idmap/' + filename.basename
    end

    def group_id_map_file
      filename.parent.parent + 'idmap/group/' + filename.basename
    end

    def partymapping
      @pmap ||= group_mapfile.mapping
    end
  end
end
