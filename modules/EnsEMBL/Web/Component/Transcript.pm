package EnsEMBL::Web::Component::Transcript;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component);


use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use CGI qw(escapeHTML);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub non_coding_error {
  my $self = shift;
  return $self->_error( 'No protein product', '<p>This transcript does not have a protein product</p>' );
}

sub _flip_URL {
  my( $transcript, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
}


sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my $seq;
  my $i = 0;
  
  my $mk = {
    'snp' => { 
      'class' => 'snt', 
      'title' => sub { return "Residues: $_[0]->{'pep_snp'}" }
    },
    'syn' => { 
      'class' => 'syn', 
      'title' => sub { my $v = shift; my $t = ''; $t .= $v->{'ambigcode'}[$_] ? '('.$v->{'ambigcode'}[$_].')' : $v->{'nt'}[$_] for (0..2); return "Codon: $t" }
    },
    'insert' => { 
      'class' => 'si', 
      'title' => sub { shift; $_->{'alleles'} = join '', @{$_->{'nt'}}; $_->{'alleles'} = Bio::Perl::translate_as_string($_->{'alleles'}); return "Insert: $_->{'alleles'}" }
    },
    'delete' => { 
      'class' => 'sd', 
      'title' => sub { return "Deletion: $_[0]->{'alleles'}" } 
    },
    'frameshift' => { 
      'class' => 'fs', 
      'title' => sub { return "Frame-shift" }
    },
    'snputr'    => { 'class' => 'snu' },
    'insertutr' => { 'class' => 'siu' },
    'deleteutr' => { 'class' => 'sdu' }
  };

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'variations'}}) {
      my $variation = $data->{'variations'}->{$_};
      my $type = $variation->{'type'};
      
      next unless $mk->{$type}; # Just in case, but shouldn't happen.
      
      if ($variation->{'transcript'}) {
        $seq->[$_]->{'title'} = "Alleles: $variation->{'alleles'}";
        $seq->[$_]->{'class'} .= ($config->{'translation'} ? $mk->{$type}->{'class'} : 'sn') . " ";
      } else {
        $seq->[$_]->{'title'} = &{$mk->{$type}->{'title'}}($variation);
        $seq->[$_]->{'class'} .= "$mk->{$type}->{'class'} ";
      }
    }
    
    $i++;
  }

  $config->{'v_space'} = "\n";
}

1;
