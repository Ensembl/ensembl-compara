=head1 NAME

EnsEMBL::Web::Component::DAS::Reference

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS::Reference;

use EnsEMBL::Web::Component::DAS;
our @ISA = qw( EnsEMBL::Web::Component::DAS);
use strict;
use warnings;

my $strand = {
	'1' => '+',
	'0' => '-',
	'-1' => '-'
	};


sub features {
    my( $panel, $object ) = @_;
    
    my $segment_tmp = qq{<SEGMENT id="%s" start="%s" stop="%s">\n};
    my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

    my $feature_template = qq{
<FEATURE id="%s">
  <START>%d</START>
  <END>%d</END>
  <ORIENTATION>%s</ORIENTATION>
  <TYPE id="%s" category="%s" reference="yes" superparts="%s" subparts="%s">%s</TYPE>
  <TARGET id="%s" start="%s" stop="%s">%s</TARGET>
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
				    $strand->{$feature->{'ORIENTATION'}} || '',
				    $feature->{'TYPE'} || '',
				    $feature->{'CATEGORY'} || '',
				    $feature->{'SUPERPARTS'} || '',
				    $feature->{'SUBPARTS'} || '',
				    $feature->{'TYPE'} || '',
				    $feature->{'TARGET_ID'} || '',
				    $feature->{'TARGET_START'} || '',
				    $feature->{'TARGET_END'} || '',
				    $feature->{'TARGET_ID'} || '',
				    ));
	    
	}
	$panel->print ( qq{</SEGMENT>\n});
    }
    $panel->print(qq{</GFF>\n});
}


sub entry_points {
    my( $panel, $object ) = @_;

    my $features = $object->EntryPoints();

    my $template = qq{<SEGMENT id="%s" start="%s" stop="%s" orientation="%s">%s</SEGMENT>\n};
    (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
    $url .= "://$ENV{SERVER_NAME}";
#    $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
    $url .="$ENV{REQUEST_URI}";

    $panel->print(sprintf("<ENTRY_POINTS href=\"%s\" version=\"1.0\">\n", $url));

    foreach my $e (@{$features || []}) {
	$panel->print(sprintf($template, @$e));
    }
 
    $panel->print(qq{</ENTRY_POINTS>\n});
}

sub dna {
    my( $panel, $object ) = @_;

    my $segment_tmp = qq{<SEQUENCE id="%s" start="%s" stop="%s" version="1.0">\n};
    my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

    my $feature_tmp = qq{<DNA length=\"%d\">\n};

    my $features = $object->DNA();

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



	$panel->print( sprintf ($feature_tmp, 
				$segment->{'STOP'}  - $segment->{'START'} + 1 ));



	my $pattern = '.{60}';
	my $seq = $segment->{'SEQ'};
	while ($seq =~ /($pattern)/g) {
	    $panel->print ("$1\n");
	}
	my $tail = length($seq) % 60;
    
	$panel->print (substr($seq, -$tail));
	$panel->print (qq{\n</DNA>\n</SEQUENCE>\n});
    }
}

sub sequence {
    my( $panel, $object ) = @_;

    my $segment_tmp = qq{<SEQUENCE id="%s" start="%s" stop="%s" version="1.0">\n};
    my $error_tmp = qq{<ERRORSEGMENT id="%s" start="%s" stop="%s" />\n};

    my $features = $object->DNA();

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



 #       $panel->print( sprintf ($feature_tmp,
 #                               $segment->{'STOP'}  - $segment->{'START'} + 1 ));


        my $pattern = '.{60}';
        my $seq = $segment->{'SEQ'};
        while ($seq =~ /($pattern)/g) {
            $panel->print ("$1\n");
        }
        my $tail = length($seq) % 60;

        $panel->print (substr($seq, -$tail));
        $panel->print (qq{\n</SEQUENCE>\n});
    }
}

1;
