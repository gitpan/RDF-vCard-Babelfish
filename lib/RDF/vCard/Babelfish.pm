package RDF::vCard::Babelfish;

use 5.008;
use common::sense;
use constant {
	FMT_HCARD       => 'HCARD',
	FMT_JCARD       => 'JCARD',
	FMT_NTRIPLES    => 'NTRIPLES',
	FMT_RDFA        => 'RDFA',
	FMT_RDFJSON     => 'RDFJSON',
	FMT_RDFXML      => 'RDFXML',
	FMT_TURTLE      => 'TURTLE',
	FMT_VCARD3      => 'VCARD3',
	FMT_VCARD4      => 'VCARD4',
	FMT_VCARDXML    => 'VCARDXML',
	};

use Digest::SHA1 qw[];
use Encode qw[];
use HTML::Microformats '0.103';
use JSON qw[];
use RDF::RDFa::Parser '1.094';
use RDF::RDFa::Generator;
use RDF::Trine '0.130';
use RDF::vCard '0.007';
use XML::LibXML;

our $VERSION = '0.007';

sub new
{
	my ($class, $from, $to) = @_;
	bless [uc $from, uc $to, {}], $class;
}

sub from
{
	my ($self, $test) = @_;
	return $self->[0] if !defined $test;
	return $self->[0] if $self->[0] eq uc $test;
	return;
}

sub to
{
	my ($self, $test) = @_;
	return $self->[1] if !defined $test;
	return $self->[1] if $self->[1] eq uc $test;
	return;
}

sub cache
{
	my ($self, $key, $value) = @_;
	
	if (defined $key and scalar(@_)==3)
	{
		my $old = $self->[2]->{$key};
		$self->[2]->{$key} = $value;
		return $old if defined $old;
		return;
	}
	
	if (defined $key)
	{
		my $old = $self->[2]->{$key};
		return $old if defined $old;
		return;
	}
	
	return $self->[2];
}

sub convert
{
	my ($self, $input, %options) = @_;
	
	my ($model, $cards) = $self->_process_input($input, %options);
	
	# Maybe just have $model but no @$cards?
	if (!@$cards)
	{
		if ($self->to(FMT_VCARD3) or $self->to(FMT_JCARD))
		{
			my $e = RDF::vCard::Exporter->new(vcard_version => 3);
			$cards = [ $e->export_cards($model) ];
		}
		elsif ($self->to(FMT_VCARD4) or $self->to(FMT_VCARDXML))
		{
			my $e = RDF::vCard::Exporter->new(vcard_version => 4);
			$cards = [ $e->export_cards($model) ];
		}
		# else:
		# we don't have @$cards, and we don't need it!
	}
	
	# vCard 3, vCard 4, vCard XML.
	my $r = $self->_process_output_from_cards($cards, %options);
	return $r if $r;

	# All serialisations of RDF.
	$r = $self->_process_output_from_model($model, %options);
	return $r if $r;
	
	die sprintf("Not a supported output format: %s\n", $self->to);
}

sub _process_input
{
	my ($self, $input, %options) = @_;

	$options{base} = sprintf('widget://%s.sha1/input',
		Digest::SHA1::sha1_hex(Encode::encode_utf8($input)));

	my ($model, @cards);

	if ($self->from(FMT_VCARD3) or $self->from(FMT_VCARD4))
	{
		my $i = RDF::vCard::Importer->new;
		@cards = $i->import_string($input);
		$model = $i->model;
	}
	
	elsif ($self->from(FMT_RDFXML) or $self->from(FMT_RDFJSON) or
	       $self->from(FMT_TURTLE) or $self->from(FMT_NTRIPLES))
	{
		$model = RDF::Trine::Model->temporary_model;
		
		my $parser = RDF::Trine::Parser->new($self->from);
		$parser->parse_into_model(
			$options{base},
			$input,
			$model,
			);
	}
	
	elsif ($self->from(FMT_RDFA))
	{
		my $parser = RDF::RDFa::Parser->new(
			$input,
			$options{base},
			RDF::RDFa::Parser::Config->tagsoup,
			);
		$model = $parser->graph;
	}
	
	elsif ($self->from(FMT_HCARD))
	{
		HTML::Microformats->modules; # force load of modules (bug: v < 0.103)
		
		my $doc = HTML::Microformats->new_document($input, $options{base});
		$doc->assume_all_profiles;
		$doc->parse_microformats;
		$model = $doc->model;
	}
	
	else
	{
		die sprintf("Not a supported input format: %s\n", $self->from);
	}
	
	return ($model, \@cards);
}

sub _process_output_from_cards
{
	my ($self, $cards) = @_;
	
	if ($self->to(FMT_VCARD3))
	{
		my $str = join("\n", @$cards);
		return $str ? $str : "\n"; # force truth
	}

	elsif ($self->to(FMT_VCARD4))
	{
		my $str = join("\n", @$cards);
		return $str ? $str : "\n"; # force truth
	}

	elsif ($self->to(FMT_JCARD))
	{
		my @jcards = map { $_->to_jcard(1) } @$cards;
		return JSON::to_json(\@jcards);
	}

	elsif ($self->to(FMT_VCARDXML))
	{
		my $document = XML::LibXML->new->parse_string(
			'<vcards xmlns="urn:ietf:params:xml:ns:vcard-4.0" />');
		
		foreach my $card (@$cards)
		{
			$card->add_to_document($document);
		}
		
		return $document->toString;
	}
	
	return;
}

sub _process_output_from_model
{
	my ($self, $model) = @_;
	
	if ($self->to(FMT_RDFXML) or $self->to(FMT_RDFJSON) or
	    $self->to(FMT_TURTLE) or $self->to(FMT_NTRIPLES) or
	    $self->to(FMT_RDFA))
	{
		my $ser = RDF::Trine::Serializer->new($self->to,
			style      => 'HTML::Pretty',
			title      => 'vCard in RDF Data',
			namespaces => {
				'vcard'  => 'http://www.w3.org/2006/vcard/ns#',
				'vx'     => 'http://buzzword.org.uk/rdf/vcardx#',
				'rdf'    => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
				});
		my $str = $ser->serialize_model_to_string($model);
		return $str ? $str : "\n"; # force truth
	}
	
	return;
}

1;

__END__

=head1 NAME

RDF::vCard::Babelfish - convert between myriad contact formats

=head1 SYNOPSIS

  use RDF::vCard::Babelfish;
  my $babelfish = RDF::vCard::Babelfish->new('HCARD' => 'VCARDXML');
  print $babelfish->convert($input_string);

=head1 QUOTES

"And the Lord descended, and we descended with him to see the city and the
tower which the children of men had built. And he confounded their language,
and they no longer understood one another's speech, and they ceased then to
build the city and the tower."
I<Jubilees 10:23-24>

"The practical upshot of all this is that if you stick a Babel fish in your
ear you can instantly understand anything in any form of language."
I<Hitchhikers 6>

"Now it is such a bizarrely improbable coincidence that anything so
mindboggingly useful could have evolved purely by chance that some thinkers
have chosen to see it as the final and clinching proof of the non-existence
of God."
I<Hitchhikers 6>

=head1 DESCRIPTION

This is a sort of supplementary module to go with L<RDF::vCard>. It adds
some cool functionality at the cost of a few additional dependencies.
It's a simple way to convert between the following formats:

  HCARD         input only
  JCARD         output only
  NTRIPLES
  RDFA
  RDFJSON
  RDFXML
  TURTLE
  VCARD3
  VCARD4
  VCARDXML      output only

For the RDF-based formats, the W3C vCard vocabulary, as described in
L<RDF::vCard::Exporter> is expected.

Some conversions are slightly lossy, but overall, even when chaining
several conversions together, results are fairly good.

=head1 TODO

Nice to have: jCard and vCardXML input; Portable Contacts.

=head1 SEE ALSO

B<hCard:> L<HTML::Microformats::Format::hCard>,
L<http://microformats.org/wiki/hcard>.

B<jCard:> L<http://microformats.org/wiki/jCard>.

B<N-Triples, RDF/JSON, RDF/XML, Turtle:> L<RDF::Trine>.

B<RDFa:> L<RDF::RDFa::Parser>, L<RDF::RDFa::Generator>,
L<http://www.w3.org/Submission/vcard-rdf/>.

B<vCard 3, vCard 4, vCard XML:> L<RDF::vCard>,
L<http://www.ietf.org/rfc/rfc2445.txt>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2011 Toby Inkster

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

