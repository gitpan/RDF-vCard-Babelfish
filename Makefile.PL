use strict;
use warnings;

use inc::Module::Install;

my $dist = 'RDF-vCard-Babelfish';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'common::sense'        => 0;
requires            'Digest::SHA1'         => 0;
requires            'Encode'               => 0;
requires            'HTML::Microformats'   => '0.103';
requires            'JSON'                 => '2.00';
test_requires       'Module::Signature'    => '0.66';
requires            'RDF::RDFa::Parser'    => '1.094';
requires            'RDF::RDFa::Generator' => 0;
requires            'RDF::Trine'           => '0.130';
requires            'RDF::vCard'           => '0.007';
test_requires       'Test::More'           => '0.61';
requires            'XML::LibXML'          => '1.70';

resources(
	'homepage'   => "http://search.cpan.org/dist/$dist/",
	'repository' => "http://goddamn.co.uk/viewvc/perlmods/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);

keywords(qw[RDF vCard hCard jCard XML Contacts Addresses Converter]);
	
write_doap_changes;
write_doap_changes_xml;

include 'Test::Signature';
auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
