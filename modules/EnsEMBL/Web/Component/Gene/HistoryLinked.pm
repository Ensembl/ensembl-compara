package EnsEMBL::Web::Component::Gene::HistoryLinked;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return "Associated archived ID's for this stable ID version";
}

sub content {
  my $self = shift;
  my $OBJ = $self->object;
  my $object = $OBJ->get_archive_object();
  
  my $assoc = get_assoc($object, $OBJ);
  if ($assoc ==0) { 
    my $html = "<p>No associated ID's found</p>";
    return $html;
  } else {
    my @associated = @$assoc;
    return "<p>No associated ID's found</p>" unless scalar @associated > 0;

    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px' } );    
    $table->add_columns (      
      { 'key' => 'release',     'title' => 'Release', },
      { 'key' => 'gene' ,       'title' => "Gene" },   
      { 'key' => 'transcript',  'title' => 'Transcript', },
      { 'key' => 'translation', 'title' => "Peptide" },  
    );  

    foreach (@associated){ 
      $table->add_row($_);
    }   

    return $table->render;
  }
}

sub get_assoc {
  my $object = shift;
  my $OBJ = shift;

  my @associated = @{ $object->get_all_associated_archived };  
  return 0 unless (@associated);

  my @sorted = sort { $a->[0]->release <=> $b->[0]->release ||
                      $a->[0]->stable_id cmp $b->[0]->stable_id } @associated;

  my $last_release;
  my $last_gsi;
  my @a; 

  while (my $r = shift(@sorted)) { 
  my %temp;
  my ($release, $gsi, $tsi, $tlsi, $pep_seq);

    # release
    if ($r->[0]->release == $last_release) {
      $release = undef;
    } else {
      $release = $r->[0]->release;
    }

    # gene
    if ($r->[0]->stable_id eq $last_gsi) {
      $gsi = undef;
    } else {
      $gsi = _idhistoryview_link($OBJ, 'Gene', 'g', $r->[0]->stable_id);
    }

    # transcript
    $tsi = _idhistoryview_link($OBJ, 'Transcript','t', $r->[1]->stable_id);
    warn $tsi;
    # translation
    if ($r->[2]) {
      $tlsi = _idhistoryview_link($OBJ,'peptide','p', $r->[2]->stable_id);
      $tlsi .= '<br />'._get_formatted_pep_seq($r->[3], $r->[2]->stable_id);
    } else {
      $tlsi = 'none';
    }

    $last_release = $r->[0]->release;
    $last_gsi = $r->[0]->stable_id;

    $temp{'release'} = $release;
    $temp{'gene'} = $gsi;
    $temp{'transcript'} = $tsi;
    $temp{'translation'} = $tlsi;
    push (@a, \%temp);
  }

  return \@a;
}


sub _idhistoryview_link {
  my ($OBJ, $type, $param, $stable_id) = @_;
  return undef unless ($stable_id);
  
  my $url = $OBJ->_url({'type' => $type, 'action' => 'Idhistory', $param => $stable_id});
  my $link = sprintf( '<a href="%s">%s</a>',
  $url,
  $stable_id); ;
  return $link;                          
}

sub _get_formatted_pep_seq {
  my $seq = shift;
  my $stable_id = shift;

  my $html;

  if ($seq) {
    $seq =~ s#(.{1,60})#$1<br />#g;
    $html = "<kbd>$seq</kbd>";
  }

  return $html;
}


1;
