# $Id$

package EnsEMBL::Web::Document::HTML::Title;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

## FIXME - this is a temporary hack until we rewrite the BLAST front end
sub new { 
  my $title = $ENV{'ENSEMBL_TYPE'} eq 'blastview' ? 'BLAST Search' : 'Untitled document';
  return shift->SUPER::new( 'title' => $title ); 
}

sub set       { $_[0]{'title'} = $_[1]; }
sub get       { return $_[0]{'title'};  }
sub set_short { $_[0]{'short'} = $_[1]; }
sub get_short { return $_[0]{'short'};  }

sub _content {
  my $self  = shift;
  my $title = encode_entities($self->strip_HTML($self->get));
  return "<title>$title</title>\n";
}

sub init {
  my $self       = shift;
  my $controller = shift;
  
  if ($controller->request eq 'ssi') {
    $self->set($controller->content =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: ' . $controller->r->uri);
  } else {
    my $node          = $controller->node;
    my $object        = $controller->object;
    my $configuration = $controller->configuration;
  
    return unless $node && ($object || $configuration);
    
    my $species_defs = $self->species_defs;
    my $caption      = $object ? $object->caption : $configuration->caption;
    my $title        = $node->data->{'concise'} || $node->data->{'caption'};
    $title           =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
    
    $self->set(sprintf '%s %s: %s %s', $species_defs->ENSEMBL_SITE_NAME, $species_defs->ENSEMBL_VERSION, $species_defs->SPECIES_BIO_NAME, " - $title - $caption");
    
    ## Short title to be used in the bookmark link
    if ($controller->hub->user) {
      my $type = $controller->type;
    
      if ($type eq 'Location' && $caption =~ /: ([\d,-]+)/) {
        (my $strip_commas = $1) =~ s/,//g;
        $caption =~ s/: [\d,-]+/:$strip_commas/;
      }
      
      $caption =~ s/Chromosome //          if $type eq 'Location';
      $caption =~ s/Regulatory Feature: // if $type eq 'Regulation';
      $caption =~ s/$type: //;
      $caption =~ s/\(.+\)$//;
      
      $self->set_short(sprintf '%s: %s', $species_defs->SPECIES_COMMON_NAME, "$title - $caption");
    }
  }
}

1;
