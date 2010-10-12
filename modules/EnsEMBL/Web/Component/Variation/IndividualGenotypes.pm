# $Id$

package EnsEMBL::Web::Component::Variation::IndividualGenotypes;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $html   = '';

  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;

  ## return if no data
  my %ind_data = %{$object->individual_table};
  
  return '<p>No individual genotypes for this SNP</p>' unless %ind_data;

  ## if data continue
  my @rows;
  my $flag_children = 0;
  
  foreach my $ind_id (sort { $ind_data{$a}{'Name'} cmp $ind_data{$b}{'Name'} } keys %ind_data) {
    my %ind_row;
    my $genotype = $ind_data{$ind_id}{'Genotypes'};
    
    next if $genotype eq '(indeterminate)';

    # Parents
    my $father = $self->format_parent($ind_data{$ind_id}{'Father'});
    my $mother = $self->format_parent($ind_data{$ind_id}{'Mother'});
    
    # Name, Gender, Desc
    my $description = uc $ind_data{$ind_id}{'Description'} || '-';
    my @populations = map $self->pop_url($_->{'Name'}, $_->{'Link'}), @{$ind_data{$ind_id}{'Population'}};

    my $pop_string = join(', ', @populations) || '-';
    my $tmp_row = {
      Individual  => "<small>$ind_data{$ind_id}{'Name'}<br />($ind_data{$ind_id}{'Gender'})</small>",
      Genotype    => "<small>$genotype</small>",
      Description => "<small>$description</small>",
      Populations => "<small>$pop_string</small>",
      Father      => "<small>$father</small>",
      Mother      => "<small>$mother</small>",
      Children    => '-'
    };

    # Children
    my $children = $ind_data{$ind_id}{'Children'};
    my @children = map { "<small>$_: $children->{$_}[0]</small>" } keys %$children;

    if (@children) {
      $tmp_row->{'Children'} = join '<br />', @children;
      $flag_children = 1;
    }

    push @rows, $tmp_row;
 } 
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'Individual asc' ] });
  
  $table->add_columns(
    { key => 'Individual',  title => 'Individual<br />(gender)',       sort => 'html' },
    { key => 'Genotype',    title => 'Genotype<br />(forward strand)', sort => 'html' },
    { key => 'Description', title => 'Description',                    sort => 'html' },
    { key => 'Populations', title => 'Populations', width => 250,      sort => 'html' },
    { key => 'Father',      title => 'Father',                         sort => 'none' },
    { key => 'Mother',      title => 'Mother',                         sort => 'none' }
  );

  $table->add_columns({ key => 'Children', title => 'Children', sort => 'none' }) if $flag_children;
  $table->add_rows(@rows);

  return $table->render;
}

sub format_parent {
  my ($self, $parent_data) = shift;
  return $parent_data && $parent_data->{'Name'} ? $parent_data->{'Name'} : '-';
}

sub pop_url {
  my ($self, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $self->hub->get_ExtURL_link($pop_name, 'DBSNPPOP', $pop_dbSNP->[0]);
}


1;
