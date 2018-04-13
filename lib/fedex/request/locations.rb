require 'fedex/request/base'
require 'fedex/locations'

module Fedex
  module Request
    class Locations < Base
      def initialize(credentials, options={})
        requires!(options, :search)
        @credentials            = credentials
        @geographic_coordinates = options[:search][:geographic_coordinates]
        @effective_date         = options[:search][:effective_date]
      end

      def process_request
        api_response = self.class.post(api_url, :body => build_xml, verify: false)
        # nearest_open_fedex_ship_center = parse_response(api_response)[:search_locations_reply][:address_to_location_relationships][:distance_and_location_details].select { |office| office[:location_detail][:location_type] == "FEDEX_AUTHORIZED_SHIP_CENTER" }[0]
        response = parse_response(api_response)
        if success?(response)
          results = response[:search_locations_reply][:address_to_location_relationships][:distance_and_location_details]
          Fedex::Locations.new(results)
        else
          error_message = if response[:search_locations_reply]
            [response[:search_locations_reply][:notifications]].flatten.first[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SearchLocationsRequest(:xmlns => "http://fedex.com/ws/locs/v#{service[:version]}"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)
            add_fedex_address_object(xml)
          }
        end
        builder.doc.root.to_xml
      end

      def add_fedex_address_object(xml)
        xml.EffectiveDate @effective_date if @effective_date != nil
        xml.LocationsSearchCriterion "GEOGRAPHIC_COORDINATES"
        xml.Address{
          xml.CountryCode 'US'
          xml.GeographicCoordinates @geographic_coordinates
        }
        xml.GeographicCoordinates @geographic_coordinates
      end

      def service
        { id: 'locs', version: 7 }
      end

      def success?(response)
        response[:search_locations_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:search_locations_reply][:highest_severity])
      end
    end
  end
end
