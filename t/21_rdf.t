use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;
use CGI::Wiki::Formatter::UseMod;
use Config::Tiny;
use URI::Escape;

use Test::More tests =>
  (1 + 22 * $CGI::Wiki::TestConfig::Utilities::num_stores);

use_ok( "OpenGuides::RDF" );

my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
  SKIP: {
      skip "$store_name storage backend not configured for testing", 22
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new(
          store     => $store,
          formatter => CGI::Wiki::Formatter::UseMod->new( munge_urls => 1 ),
      );
      my $config = Config::Tiny->read( "t/21_wiki.conf" );

      my $rdf_writer = eval {
          OpenGuides::RDF->new( wiki   => $wiki,
                                config => $config
          );
      };
      is( $@, "",
         "'new' doesn't croak if wiki and config objects supplied"
      );
      isa_ok( $rdf_writer, "OpenGuides::RDF" );

      # Test the data for a node that exists.
      my $rdfxml = $rdf_writer->emit_rdfxml( node => "Calthorpe Arms" );

      like( $rdfxml, qr|<\?xml version="1.0"\?>|,
            "RDF is encoding-neutral" );

      like( $rdfxml, qr|<wn:Neighborhood>Bloomsbury</wn:Neighborhood>|,
	    "finds the first locale" );
      like( $rdfxml, qr|<wn:Neighborhood>St Pancras</wn:Neighborhood>|,
	    "finds the second locale" );

      like( $rdfxml, qr|<phone>test phone number</phone>|,
	    "picks up phone number" );

      like( $rdfxml, qr|<chefmoz:Hours>test hours</chefmoz:Hours>|,
	    "picks up opening hours text" );

      like( $rdfxml, qr|<homePage>test website</homePage>|,
	    "picks up website" );

      like( $rdfxml,
	   qr|<dc:title>CGI::Wiki Test Site: Calthorpe Arms</dc:title>|,
	    "sets the title correctly" );

      like( $rdfxml, qr|<dc:contributor>Kake</dc:contributor>|,
	    "last username to edit used as contributor" );

      like( $rdfxml, qr|<wiki:version>1</wiki:version>|, "version picked up" );

      like( $rdfxml, qr|<rdf:Description rdf:about="">|, "sets the 'about' correctly" );

      like( $rdfxml, qr|<dc:source rdf:resource="http://wiki.example.com/mywiki.cgi\?id=Calthorpe_Arms" />|,
	    "set the dc:source with the version-independent uri" );

      like( $rdfxml, qr|<country>United Kingdom</country>|,
	    "default country picked up" ).
      like( $rdfxml, qr|<city>London</city>|,
	    "default city picked up" ).
      like( $rdfxml, qr|<postalCode>WC1X 8JR</postalCode>|,
	    "postcode picked up" );
      like( $rdfxml, qr|<geo:lat>51.524193</geo:lat>|,
	    "latitude picked up" );
      like( $rdfxml, qr|<geo:long>-0.114436</geo:long>|,
	    "longitude picked up" );

      like( $rdfxml, qr|<dc:date>|, "date element included" );
      unlike( $rdfxml, qr|<dc:date>1970|, "hasn't defaulted to the epoch" );


      # Now test that there's a nice failsafe where a node doesn't exist.
      $rdfxml = eval {
          $rdf_writer->emit_rdfxml( node => "I Do Not Exist" );
      };
      is( $@, "",
           "->emit_rdfxml doesn't die when called on a nonexistent node" );

      like( $rdfxml, qr|<wiki:version>0</wiki:version>|,
            "...and wiki:version is 0" );

      #print $rdfxml;
  }
}
