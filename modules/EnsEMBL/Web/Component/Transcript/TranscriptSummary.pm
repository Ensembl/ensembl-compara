package EnsEMBL::Web::Component::Transcript::TranscriptSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $table         = new EnsEMBL::Web::Document::HTML::TwoCol;
  my $sp     = $object->species_defs->SPECIES_COMMON_NAME;

## add transcript stats
  my $exons     = @{ $object->Obj->get_all_Exons };
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;

  my $HTML = "
	  <strong>Exons:</strong> $exons 
	  <strong>Transcript length:</strong> $basepairs bps";
     $HTML .= "
          <strong>Translation length:</strong> $residues residues" if $residues;
  $table->add_row('Statitics',
		  "<p>$HTML</p>",
		  1 );

## add CCDS info
  if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
    my %T = map { $_->primary_id,1 } @CCDS;
     @CCDS = sort keys %T;
     $table->add_row('CCDS',
		     "<p>This transcript is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }</p>",
		     1, );
  }

## add alternative transcript links
  my @alts;
  if (my @poss_alts = grep { $_->type eq 'ALT_TRANS' } @{$object->Obj->get_all_DBLinks} ) {
      #filter out duplicate or unwanted xrefs
      my %names_to_filter;
      foreach my $alt (@poss_alts) {
	  next unless ($alt->display_id =~ /OTT|ENST/);
	  push @{$names_to_filter{$alt->dbname}}, $alt;
      }
      foreach my $type (qw(
			   shares_CDS_and_UTR_with_OTTT
			   ENST_ident
			   shares_CDS_with_OTTT
			   ENST_CDS
			   OTTT ) ) {
	  if ( $names_to_filter{$type}) {
	      @alts = @{$names_to_filter{$type}};
	      last;
	  }
      }
      @alts = @poss_alts unless @alts;
  }
  my $txt = join ', ', map {$_->db_display_name .': '. $object->get_ExtURL_link($_->display_id, $_->dbname, $_->display_id)} @alts;
  $table->add_row('Alternative Transcripts',
		  "<p>$txt</p>",
		  '1');

## add prediction method
  my $db    = $object->get_db ;
  my $label = ( ($db eq 'vega' or $object->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
  my $text  = "No $label defined in database";
  my $o     = $object->Obj;
  eval {
    if( $o && $o->can( 'analysis' ) && $o->analysis && $o->analysis->description ) {
    $text = $o->analysis->description;
    } elsif( $object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description ) {
      $text = $object->gene->analysis->description;
    } else {
      my $logic_name = $o->can('analysis') && $o->analysis ? $o->analysis->logic_name : '';
      if( $logic_name ){
        my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
        $text = "<strong>FROM CONFIG:</strong> ".$object->species_defs->$confkey;
      }
      if( ! $text ){
        my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
        $text   = "<strong>FROM DEFAULT CONFIG:</strong> ".$object->species_defs->$confkey;
      }
    }
  };
  $table->add_row($label,
		  $text,
		  1 );

## add alternative transcript info
  my $temp =  $self->_matches( 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
  if (my $temp) {
      $table->add_row('Alternative transcripts',
		      "<p>$temp</p>",
		      1 );
  }

## add pepstats info
  $table->add_row('Peptide statistics',
		  '<p>## Peptide statistics section will go here ##</p>',
		  1 );

  return $table->render;
}

#sub alternative_transcripts {
#  my( $panel, $transcript ) = @_;
#  _matches( $panel, $transcript, 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
#}


1;
