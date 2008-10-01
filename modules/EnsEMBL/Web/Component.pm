package EnsEMBL::Web::Component;

use strict;
use Data::Dumper;
$Data::Dumper::Indent = 3;
use EnsEMBL::Web::File::Text;
use Exporter;
use CGI qw(escape);
use EnsEMBL::Web::Document::SpreadSheet;
use Text::Wrap qw(wrap);

use base qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(cache cache_print);
our @EXPORT    = @EXPORT_OK;

sub image_width {
  my $self = shift;

  return $ENV{'ENSEMBL_IMAGE_WIDTH'};
}
sub new {
  my( $class, $object ) = shift;
  my $self = {
    'object' => shift,
  };
  bless $self,$class;
  $self->_init();
  return $self;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache_key {
  return undef;
}

sub _init {
  return;
}

sub caption {
  return undef;
}
sub cache {
  my( $panel, $obj, $type, $name ) = @_;
  my $cache = new EnsEMBL::Web::File::Text( $obj->species_defs );
  $cache->set_cache_filename( $type, $name );
  return $cache;
}

sub cache_print {
  my( $cache, $string_ref ) =@_;
  $cache->print( $$string_ref ) if $string_ref;
}

sub site_name {
  my $self = shift;
  our $sitename = $SiteDefs::ENSEMBL_SITETYPE eq 'EnsEMBL' ? 'Ensembl' : $SiteDefs::ENSEMBL_SITETYPE;
  return $sitename;
}

sub _matches {
  my(  $self, $key, $caption, @keys ) = @_;

  my $transcript = $self->object;

  my $label      = $transcript->species_defs->translate( $caption );
  my $trans      = $transcript->transcript;
  # Check cache

  unless ($transcript->__data->{'links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($trans)};
    return unless (@similarity_links);
    $self->_sort_similarity_links( @similarity_links);
  }

  my @links = map { @{$transcript->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;

  my $db = $transcript->get_db();
  my $entry = $transcript->gene_type || 'Ensembl';

  # add table call here
  my $html;
  if ($transcript->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = qq(<p></p>);
  }
  else {
    $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  }
  $html .= qq(<table cellpadding="4">);
  if( $keys[0] eq 'ALT_TRANS' ) {
      @links = $self->remove_redundant_xrefs(@links);
  }
  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);

  return $html;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $object           = $self->object;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;
  my (%affy, %exdb);
  # @ice names
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links ) {
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    if( $externalDB eq "GO" ){
      push @{$object->__data->{'links'}{'go'}} , $display_id;
      next;
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}} , $type ;
      next;
    }
    my $text = $display_id;
    (my $A = $externalDB ) =~ s/_predicted//;
    if( $urls and $urls->is_linked( $A ) ) {
      my $link;
      $link = $urls->get_url( $A, $primary_id );

      my $word = $display_id;
      if( $A eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
#    warn $externalDB;
#    warn $type->db_display_name;
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';
      $join_links = 1;
    }
    if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) &&
      ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
      $text .= sprintf( ' [<a href="/%s/Transcript/ExternalRecordAlignment?t=%s;sequence=%s;db=%s">align</a>] ',
                  $object->species, $object->stable_id, $seq_arg, $db );
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $type->description ) {
      ( my $D = $type->description ) =~ s/^"(.*)"$/$1/;
      $text .= "<br />".CGI::escapeHTML($D);
      $join_links = 1;
    }
 if( $join_links  ) {
      $text = qq(\n <div>$text</div>);
    } else {
      $text = qq(\n <div class="multicol">$text</div>);
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      next if ($affy{$display_id} && $exdb{$type->db_display_name}); ## remove duplicates
      $text = "\n".'  <div class="multicol"><a href="' .$urls->get_url('AFFY_FASTAVIEW', $display_id) .'">'. $display_id. '</a></div>';
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ] ;
#    warn $text;
  }
#  return $object->__data->{'similarity_links'};
}

sub remove_redundant_xrefs {
  my ($self,@links) = @_;
  my %priorities;
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if ($text =~ />OTT|>ENST/) {
      $priorities{$key} = $text;
    }
  }
  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcripts') {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  return @links;
}

sub _warn_block {
### Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
### data structures etc... 
### output looks like:
###
###  ###########################
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  ###########################
###

  my $self = shift;

  my $width       = 128;
  my $border_char = '#';
  my $template = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line     = $border_char x $width;
  warn "\n";
  warn "$line\n";
  $Text::Wrap::columns = $width-4;
  foreach my $l (@_) {
    warn sprintf $template;
    my $lines = wrap( "","", $l );
    foreach ( split /\n/, $lines ) { 
      warn sprintf $template, $_;
    }
  }
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}
1;
