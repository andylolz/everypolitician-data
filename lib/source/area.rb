require_relative 'plain_csv'
require 'field_serializer'

module Source
  class Area < PlainCSV
    class Row
      include FieldSerializer

      def initialize(r, reconciliation_data)
        @area = r
        @reconciliation_data = reconciliation_data
      end

      field :id do
        reconciliation_data[area[:id]]
      end

      field :identifiers do
        [other_identifiers, wikidata_identifier].flatten.compact
      end

      field :other_names do
        area.select { |k, v| v && k.to_s.start_with?('name__') }.map do |k, v|
          {
            lang: k.to_s[/name__(\w+)/, 1],
            name: v,
            note: 'multilingual',
            # TODO: credit the source
            # source: 'wikidata',
          }
        end
      end

      private

      attr_reader :area, :reconciliation_data

      def wikidata_identifier
        {
          identifier: area[:id],
          scheme:     'wikidata',
        }
      end

      def other_identifiers
        area.select { |k, v| v && k.to_s.start_with?('identifier__') }.map do |k,v|
          {
            identifier: v,
            scheme: k.to_s.sub('identifier__',''),
          }
        end
      end
    end

    def to_popolo
      {
        areas: area_data,
      }
    end

    def reconciliation_file
      Pathname.new('sources/') + i(:merge)[:reconciliation_file]
    end

    private

    def area_data
      as_table.map { |area| Row.new(area, reconciliation_data).to_h }
              .reject { |a| a[:id].nil? }
    end

    def reconciliation_data
      raise 'Area reconciliation file missing' unless reconciliation_file.exist?
      @rd ||= ::CSV.table(reconciliation_file, converters: nil).map do |r|
        [r[:wikidata], r[:id]]
      end.to_h
    end
  end
end
