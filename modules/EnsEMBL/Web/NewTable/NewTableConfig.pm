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

package EnsEMBL::Web::NewTable::NewTableConfig;

use strict;
use warnings;

use EnsEMBL::Web::NewTable::Config;

use parent qw(EnsEMBL::Web::NewTable::Config);

sub new {
  my ($proto,$hub,$type,$klass) = @_;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new($hub,{ type => $type, class => $klass });
  $self->{'phases'} = [{ name => undef }];
  bless $self,$class;
  return $self;
}

sub add_plugin {
  my $self = shift;
  return $self->_add_plugin(@_);
}

sub add_column {
  my ($self,$key,$type,$args) = @_;

  my @type = split(' ',$type);
  $type = shift @type;
  my $confstr = "";
  push @{$self->{'colorder'}},$key;
  $self->{'columns'}{$key} =
    EnsEMBL::Web::NewTable::Column->new($self,$type,$key,\@type,$args); 
  return $self->{'columns'}{$key};
}

sub add_phase {
  my ($self,$name,$era,$rows,$cols) = @_;

  $self->{'phases'} = [] unless defined $self->{'phases'}[0]{'name'};
  push @{$self->{'phases'}},{
    name => $name,
    rows => $rows,
    cols => $cols,
    era => $era || $name,
  };    
}

1;
