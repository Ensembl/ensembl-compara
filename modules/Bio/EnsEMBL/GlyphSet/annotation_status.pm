package Bio::EnsEMBL::GlyphSet::annotation_status;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::MiscFeature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

sub my_label { 
    return "Annotation";
}

sub features {
    my $self = shift;

    ## only display the track if species has partial annotation
    return unless (EnsWeb::species_defs->ANNOTATION_STATUS eq 'PARTIAL');

    &eprof_start('annot');
    
    my $Container = $self->{'container'};
    my $db = EnsEMBL::DB::Core::get_databases('vega');
    my $cl_info_adaptor = $db->{'vega'}->get_CloneInfoAdaptor;
    my @features;

    ## get all clones on slice
    foreach my $segment (@{$Container->project('clone') || []}) {
        my $start = $segment->from_start;
        my $end = $segment->from_end;
        my $cl_slice  = $segment->to_Slice;
        my $dbID = $cl_slice->adaptor->get_seq_region_id($cl_slice);

        ## check if clone has been annotated
        my $is_annotated = 0;
        my $cl_info = $cl_info_adaptor->fetch_by_cloneID($dbID);
        if ($cl_info) {
            foreach my $remark ($cl_info->remark) {
                if ($remark->remark eq 'Annotation_remark- annotated') {
                    $is_annotated = 1;
                    last;
                }
            }
        }

        ## return a MiscFeature if the clone is not annotated
        unless ($is_annotated) {
            my $feat = Bio::EnsEMBL::MiscFeature->new(
                -START => $start,
                -END => $end,
                -STRAND => 0,
                -SLICE => $cl_slice
            );
            push @features, $feat;
        }
    }

    &eprof_end('annot');
    #&eprof_dump(\*STDERR);

    return \@features;
}

sub tag {
    my ($self, $f) = @_;
    return {
        'style' => 'join',
        'tag' => $f->{'start'}.'-'.$f->{'end'},
        'colour' => 'gray85'
    };
}

sub zmenu {
    return { 
        'caption' => 'No manual annotation',
    };
}

sub colour {
    return 'gray50';
}

1;
