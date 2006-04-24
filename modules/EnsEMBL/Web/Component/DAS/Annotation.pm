=head1 NAME

EnsEMBL::Web::Component::DAS::Annotation

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS::Annotation;

use EnsEMBL::Web::Component::DAS;
our @ISA = qw( EnsEMBL::Web::Component::DAS);
use strict;
use warnings;

sub features {
    my( $panel, $object ) = @_;

    my $segment_tmp = qq{<SEGMENT id="%s" start="%s" stop="%s">\n};
    my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

    my $feature_template = qq{
<FEATURE id="%s">
  <START>%d</START>
  <END>%d</END>
  <TYPE id="%s">%s</TYPE>
  <METHOD id="%s">%s</METHOD>
  <ORIENTATION>%s</ORIENTATION>
</FEATURE>
};



    my $features = $object->Features();
    (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
    $url .= "://$ENV{SERVER_NAME}";
#    $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
    $url .="$ENV{REQUEST_URI}";

    $panel->print(qq{<GFF version="1.01" href="$url">\n});
    foreach my $segment (@{$features || []}) {
	if ($segment->{'TYPE'} && $segment->{'TYPE'} eq 'ERROR') {
	    $panel->print( sprintf ($error_tmp, 
				$segment->{'REGION'},
				$segment->{'START'} || '',
				$segment->{'STOP'} || ''));
	    next;
	}

	$panel->print( sprintf ($segment_tmp, 
				$segment->{'REGION'},
				$segment->{'START'} || '',
				$segment->{'STOP'} || ''));

	foreach my $feature (@{$segment->{'FEATURES'} || []}) {

	    $panel->print( sprintf ($feature_template, 
				    $feature->{'ID'} || '',
				    $feature->{'START'} || '',
				    $feature->{'END'} || '',
				    $feature->{'TYPE'}|| '',
				    $feature->{'TYPE'} || '',
				    $feature->{'METHOD'} || '',
				    $feature->{'METHOD'} || '',
				    $feature->{'ORIENTATION'} || '',

				    ));
	    
	}
	$panel->print ( qq{</SEGMENT>\n});
    }
    $panel->print(qq{</GFF>\n});
}

1;
