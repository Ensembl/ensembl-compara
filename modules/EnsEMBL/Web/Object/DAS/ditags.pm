=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Object::DAS::ditags;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

use Bio::EnsEMBL::Map::DBSQL::DitagFeatureAdaptor;

my $analysis_predicate = sub {
  $_[0]->logic_name !~ m/cage/i;
};
#my %ditag_analysis = (
#	fantom_gsc_pet => 1, # mouse
#	fantom_gis_pet => 1, # mouse
#	fantom_gsc_pet_raw => 1, # mouse and human
#	fantom_gis_pet_raw => 1, # mouse and human
#	medaka_5psage=> 1, # medaka
#	);

sub Types {
    my $self = shift;

    my @features;
    my $dba = $self->database('core', $self->real_species);

    my $dfa = $dba->get_DitagFeatureAdaptor;
    my $da = $dba->get_DitagAdaptor;

    if (my @segments = $self->Locations) {
      foreach my $s (@segments) {
        if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
            push @features, $s;
            next;
        }
        my $slice = $s->slice;
	my $tHash;
        foreach my $ft (@{$dfa->fetch_all_by_Slice($slice) || [] }) {
	  next unless &{ $analysis_predicate }($ft->analysis);
	  $tHash->{ $ft->analysis->logic_name } ++;
        }

	my @tarray = map { {id=>$_, text=>$tHash->{$_}} } sort keys %{$tHash ||{}};
	push @features, {
	    REGION => $slice->seq_region_name,
	    START => $slice->start,
	    STOP => $slice->end,
	    FEATURES => \@tarray,
	}
      }
    } else {
	my $tHash;
        foreach my $ft (@{$dfa->fetch_all || [] }) {
	  next unless &{ $analysis_predicate }($ft->analysis);
	  $tHash->{ $ft->analysis->logic_name } ++;
        }
	my @tarray = map { {id=>$_, text=>$tHash->{$_}} } sort keys %{$tHash ||{}};
	push @features, {
	    REGION => '*',
	    FEATURES => \@tarray,
	}
    }
    return \@features;
}


sub Features {
    my $self = shift;

    my $species = $self->real_species;
    my $dba = $self->database('core', $self->real_species);


    my @segments = $self->Locations;
    my @features;

    my %fts = map {$_ => 1} grep {$_}  @{$self->FeatureTypes || []};
    my $filter = %fts;

    my $dfa = $dba->get_DitagFeatureAdaptor; 
    my $da = $dba->get_DitagAdaptor;

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}
	my $slice = $s->slice;
	my @segment_features;

	foreach my $ft (sort {$a->start <=> $b->start} @{$dfa->fetch_all_by_Slice($slice) || [] }) {
	    next unless &{ $analysis_predicate }($ft->analysis);
	    my $ftype = $ft->analysis->logic_name;
	    next unless (! $filter || $fts{$ftype});

	    my $tag_count = $da->fetch_by_dbID($ft->ditag_id)->tag_count();

	    my $id = join('.', $ft->ditag_id, $ft->ditag_pair_id);
	    my $g_location = "Location: ".join(' - ', ($ft->get_ditag_location)[0,1]);

	    my $group = {
		'ID' => $id,
		'LINK' => [ {text => 'More info', href => "http://www.ensembl.org/$species/ditags/$ftype.html"} ],
		'TYPE' =>  join('-', $ftype,$ft->ditag_side),
		'NOTE'        => ["tag_count: $tag_count", $g_location],
	    };
	    $id = join('.', $id, $ft->ditag_side);

	    my $f = {
		'ID'          => $id,
		'LABEL'       => $ft->ditag_id,
		'TYPE' =>  join('-', $ftype,$ft->ditag_side),
#		'TYPE'        => $ftype,
	#	'CATEGORY'        => $ft->ditag_side || '', 
		'METHOD'      => $ftype,
                'START'       => $ft->seq_region_start,
                'END'         => $ft->seq_region_end,
                'ORIENTATION' => $self->ori($ft->seq_region_strand),
		'NOTE'        => ["tag_count: $tag_count"],
		'GROUP' => [$group], 
	    };
	    push @segment_features, $f;
	}

	push @features, {
    	    'REGION' => $s->seq_region_name, 
	    'START'  => $s->seq_region_start, 
	    'STOP'   => $s->seq_region_end,
	    'FEATURES' => \@segment_features
	    };
    }
    return \@features;
}

sub Stylesheet {
    my $self = shift;
    return qq{
<STYLESHEET version="1.0">
 <CATEGORY id="default">
    <TYPE id="FANTOM_GSC_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GSC_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GIS_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GIS_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="GIS_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="GIS_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="CHIP_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="CHIP_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="default">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>royalblue1</BGCOLOR>
           <FGCOLOR>royalblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
   </CATEGORY>


 
  <CATEGORY id="group">
    <TYPE id="FANTOM_GSC_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GSC_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GIS_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="FANTOM_GIS_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="GIS_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="GIS_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue1</BGCOLOR>
           <FGCOLOR>lightblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="CHIP_PET-R">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="CHIP_PET-L">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>darkolivegreen1</BGCOLOR>
           <FGCOLOR>darkolivegreen1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
    <TYPE id="default">
      <GLYPH>
         <ANCHORED_ARROW>
           <HEIGHT>10</HEIGHT>
           <BGCOLOR>royalblue1</BGCOLOR>
           <FGCOLOR>royalblue1</FGCOLOR>
           <BAR_STYLE>line</BAR_STYLE>
           <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
  </CATEGORY>

</STYLESHEET>
};
}

1;
