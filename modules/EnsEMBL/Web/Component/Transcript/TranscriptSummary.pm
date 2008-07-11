package EnsEMBL::Web::Component::Transcript::TranscriptSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $html   = '';
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
  $html .= "
    <dt>Statistics</dt>
      <dd>
        <p>$HTML
	</p>
     </dd>"; 

## add CCDS info
  if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
    my %T = map { $_->primary_id,1 } @CCDS;
     @CCDS = sort keys %T;
     $html .= qq(
    <dt>CCDS</dt>
      <dd><p>This transcript is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }</p></dd>);
  }
    

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
    $html .= qq(
      <dt>$label</dt>
        <dd><p>$text</p></dd>);
  };

## add alternative transcript info
  my $temp =  $self->_matches( 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
  if (my $temp) {
    $html .= qq(
    <dt>Alternative transcripts</dt>
      <dd><p>$temp</p></dd>);


  }

## add pepstats info
  $html .= qq(
    <dt>Peptide statistics</dt>
      <dd><p>## Peptide statistics section will go here ##</p></dd>);

  $html .= "</dl>";

  return $html;
}

#sub alternative_transcripts {
#  my( $panel, $transcript ) = @_;
#  _matches( $panel, $transcript, 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
#}


1;
