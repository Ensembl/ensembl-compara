=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Renderer::Excel::CellFormat;

use strict;

sub new {
  my ($class, $args) = @_;
  
  my $self = {
    alignments => {
      center => 'center',
      centre => 'center',
      c      => 'center',
      right  => 'right',
      r      => 'right',
      left   => 'left',
      l      => 'left'
    },
    valignments => {
      middle => 'middle',
      m      => 'middle',
      top    => 'top',
      t      => 'top',
      bottom => 'bottom',
      b      => 'bottom'
    },
    rowspan => 1,
    colspan => 1,
    bgcolor => 'ffffff',
    fgcolor => '000000',
    %$args,
    # set the following values after args to force their defaults
    align   => 'left',
    valign  => 'middle',
    bold    => 0,
    italic  => 0
  };
  
  bless $self, $class;
  
  # Set values set by code
  $self->set_valid_align($args->{'align'})   if exists $args->{'align'};
  $self->set_valid_valign($args->{'valign'}) if exists $args->{'valign'};
  $self->set_valid_bold($args->{'bold'})     if exists $args->{'bold'};
  $self->set_valid_italic($args->{'italic'}) if exists $args->{'italic'};
  
  return $self;
}

sub align    :lvalue { $_[0]->{'align'};    }
sub valign   :lvalue { $_[0]->{'valign'};   }
sub bgcolor  :lvalue { $_[0]->{'bgcolor'};  }
sub fgcolor  :lvalue { $_[0]->{'fgcolor'};  }
sub rowspan  :lvalue { $_[0]->{'rowspan'};  }
sub colspan  :lvalue { $_[0]->{'colspan'};  }
sub bold     :lvalue { $_[0]->{'bold'};     }
sub italic   :lvalue { $_[0]->{'italic'};   }
sub format   :lvalue { $_[0]->{'format'};   }
sub colour   :lvalue { $_[0]->{'colour'};   }
sub workbook :lvalue { $_[0]->{'workbook'}; }

sub key {
  my $self = shift;

  return join '::', 
    $self->align,
    $self->valign,
    $self->bgcolor,
    $self->fgcolor,
    $self->rowspan,
    $self->colspan,
    $self->italic,
    $self->bold;
}

sub set_valid_align {
  ### Sets horizontal alignment after checking value is valid
  my ($self, $val) = @_; 
  $self->align = $self->{'alignments'}->{$val} if exists $self->{'alignments'}->{$val};
}

sub set_valid_valign {
  ### Sets vertical alignment after checking value is valid
  my ($self, $val) = @_; 
  $self->valign = $self->{'valignments'}->{$val} if exists $self->{'valignments'}->{$val};
}

sub set_valid_bold {
  my ($self, $val) = @_; 
  $self->bold = $val if $val eq '0' or $val eq '1';
}

sub set_valid_italic {
  my ($self, $val) = @_; 
  $self->italic = $val if $val eq '0' or $val eq '1';
}

sub evaluate {
  my $self      = shift;
  my $key       = $self->key;
  my $f_hashref = $self->format;
  
  if (!exists $f_hashref->{$key}) {
    my $format = $self->workbook->add_format(
      bold     => $self->bold,
      italic   => $self->italic,
      bg_color => $self->_colour($self->bgcolor),
      color    => $self->_colour($self->fgcolor),
      align    => $self->align,
      valign   => $self->valign,
    );
    
    $f_hashref->{$key} = $format;
  }
  
  return $f_hashref->{$key};
}  

sub _colour {
  my ($self, $hex) = @_;
  
  my $c_hashref = $self->colour;
  
  if (!exists $c_hashref->{$hex}) {
    if ($c_hashref->{'_max_value'} < 63) {
      $c_hashref->{'_max_value'}++;
      $c_hashref->{$hex} = $self->workbook->set_custom_color($c_hashref->{'_max_value'}, "#$hex");
    } else {
      $c_hashref->{$hex} = undef;
    }
  }
  
  return $c_hashref->{$hex};
}

1;
