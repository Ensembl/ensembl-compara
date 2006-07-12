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
<FEATURE id="%s" %s>
  <START>%d</START>
  <END>%d</END>
  <TYPE id="%s">%s</TYPE>
  <METHOD id="%s">%s</METHOD>
  <ORIENTATION>%s</ORIENTATION>
  %s
  %s
  %s
</FEATURE>
};

    my $link_template = qq{\n<LINK href="%s">%s</LINK>};
    my $note_template = qq{\n<NOTE>%s</NOTE>};

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
	    my $group_tag = '';

	    if (my @groups = @{$feature->{'GROUP'} || []}) {
		foreach my $g (@groups) {
		    my $tag = sprintf(qq{<GROUP id="%s" %s %s>}, $g->{'ID'}, $g->{'TYPE'} ? qq{type="$g->{'TYPE'}"} : '', $g->{'LABEL'} ? qq{label="$g->{'LABEL'}"} : '');

		    if ( my @links = @{$g->{'LINK'} || []}) {
			foreach my $l (@links) {
			    $tag .= sprintf($link_template, $l->{href}, $l->{text} || $l->{href});
			}
		    }

		    if ( my @notes = @{$g->{'NOTE'} || []}) {
			foreach my $n (@notes) {
			    $tag .= sprintf($note_template, $n);
			}
		    }
		    $tag .="\n</GROUP>";
		    $group_tag .= "\n$tag";
		}

	    }


	    my $link_tag = '';
	    if ( my @links = @{$feature->{'LINK'} || []}) {
		foreach my $l (@links) {
		    $link_tag .= sprintf($link_template, $l->{href}, $l->{text} || $l->{href});
		}
	    }

	    my $note_tag = '';
	    if ( my @notes = @{$feature->{'NOTE'} || []}) {
		foreach my $n (@notes) {
		    $note_tag .= sprintf($note_template, $n);
		}
	    }


	    $panel->print( sprintf ($feature_template, 
				    $feature->{'ID'} || '', 
				    $feature->{'LABEL'} ? qq{ label="$feature->{'LABEL'}"} : '',
				    $feature->{'START'} || '',
				    $feature->{'END'} || '',
				    $feature->{'TYPE'}|| '',
				    $feature->{'TYPE'} || '',
				    $feature->{'METHOD'} || '',
				    $feature->{'METHOD'} || '',
				    $feature->{'ORIENTATION'} || '',
				    $group_tag,
				    $link_tag,
				    $note_tag,

				    ));
	    
	}
	$panel->print ( qq{</SEGMENT>\n});
    }
    $panel->print(qq{</GFF>\n});
}

sub stylesheet {
    my( $panel, $object ) = @_;

    $panel->print($object->Stylesheet());
}

1;
