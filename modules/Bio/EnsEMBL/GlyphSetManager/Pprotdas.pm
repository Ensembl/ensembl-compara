package Bio::EnsEMBL::GlyphSetManager::Pprotdas;

use strict;
use Sanger::Graphics::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::Pprotdas;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::GlyphSetManager);

sub init {
    my ($self) = @_;

    my $Config = $self->{'config'};
    my $protein = $self->{'container'};

    # Get features. The data structure returned is YUK!
    my $feat_container = $protein->get_all_DASFeatures();
    ref( $feat_container ) ne 'HASH' and return; # Sanity check

    # Examine the data structure, and create glyphs accordingly
    my %feats_by_glyph;
    foreach my $dsn( keys( %$feat_container ) ){
	my $sub_feat_container = $feat_container->{$dsn};
	ref( $sub_feat_container ) ne 'ARRAY' and next; # Another sanity check
	my $feat_ref = $sub_feat_container->[1];
	if( ref( $feat_ref ) ne 'ARRAY' or ! scalar @$feat_ref ){ next }

	# OK - we now have a list of DASSeqFeature objs. Sort them per-glyph
	foreach my $feat( @$feat_ref ){

	    # Skip protein-wide features (GeneDAS - tabulated elsewhere )
	    # GeneDAS Identified by DAS segment id eq DAS feature id
	    my $id = $feat->das_id();
		if( $feat->das_segment->ref() eq $id) { next; }	
#	    if( $feat->das_segment_id() =~ /^$id/ ){ next; }

	    # Push feature onto appropriate glyph key (by feature type)
	    my $type = $dsn . '_' . $feat->das_type_id() || 'UNKNOWN';
	    $feats_by_glyph{$type} ||= [];
	    push @{$feats_by_glyph{$type}}, $feat
	}
    }

    foreach my $das_source_name( keys %feats_by_glyph ) {
	my $extra_config = {};
	$extra_config->{'name'}     = $das_source_name;
	$extra_config->{'features'} = $feats_by_glyph{$das_source_name};
	$self->add_glyphset( $extra_config );
    }
    return 1;
}

sub add_glyphset {
    my ($self,$config) = @_;	
    my $glyphset;
    eval {
	$glyphset = new Bio::EnsEMBL::GlyphSet::Pprotdas
	  ( $self->{'container'},
	    $self->{'config'},
	    $self->{'highlights'},
	    $self->{'strand'},
	    $config );
    };

    if($@) {
	print STDERR "DAS GLYPHSET $config->{'name'} failed\n";
	return undef();
    }

    push @{$self->{'glyphsets'}}, $glyphset;
    return 1;
}

1;
