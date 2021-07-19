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

package EnsEMBL::Web::Component::StructuralVariation::PopulationFrequency;

use strict;
use Bio::EnsEMBL::Variation::Utils::Constants qw(%VARIATION_CLASSES);

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $sv_object = $object->Obj;
 
  my $html;
 
  my $svpf_adaptor = $sv_object->adaptor->db->get_StructuralVariationPopulationFrequency;

  my $frequency_data = $svpf_adaptor->fetch_all_by_StructuralVariation($sv_object);

  my $table_rows = $self->table_data($frequency_data);
  my $table      = $self->new_table([], [], { data_table => 1 });

  if (scalar(@$table_rows) != 0) {
    $self->add_table_columns($table);
    $table->add_rows(@$table_rows);

    my %display_pop;
    my %pops = map { $_->population->name => $_->population } @$frequency_data;
    foreach my $pop_name (keys(%pops)) {

      my $display_name = $pops{$pop_name}->display_group_name;
      $display_pop{$display_name} = 1 if ($display_name);
    }
    
    if (scalar(keys(%display_pop)) == 1) {
      my $pop_display = (keys(%display_pop))[0];
      $html .= qq{<h3>$pop_display allele frequency</h3>};
    }
    else {
      $html .= qq{<h3>Allele frequency</h3>};
    }
    $html .= $table->render;
  }
  return $html;
}


sub add_table_columns {
  my ($self, $table) = @_;

  $table->add_columns(
    { key => 'pop_name', title => 'Population'                     , align => 'left', sort => 'none' },
    { key => 'pop_size', title => 'Size'                           , align => 'left', sort => 'none' },
    { key => 'a_freqs',  title => 'Allele type: frequency (count)' , align => 'left', sort => 'none' },
    { key => 'freqs',    title => 'Non-reference frequency (count)', align => 'left', sort => 'none' },
  );

  return $table;
}

sub table_data {
  my ($self, $data) = @_;

  my $hub        = $self->hub;
  my $object     = $self->object;
 
  my (@rows, %pops, %pop_data, $tree, $all);

  # Get population structure
  foreach my $svpf (@$data) {

    my $pop = $svpf->population;
    my $pname  = $pop->name;
    my $pop_id = $pop->dbID;
    $pop_data{$pop_id} = $svpf;
  

    if ($pname =~ /(\W+|_)ALL/) {
      $all = $pop_id;
      next;
    }

    my $hash = $self->extra_pop($pop,"super");
    my ($super) = keys %{$hash||{}};
    if ($super) {
      $tree->{$super}{'children'}{$pop_id} = $pname;
      $tree->{$super}{'name'} = $hash->{$super}{'Name'} if (!$tree->{$super}{'name'});
    }
    else {
      $tree->{$pop_id}{'name'} = $pname;
    }  
  }

  my @ids;
  push @ids, $all if $all;
  my @super_order = sort {$tree->{$a}{'name'} cmp $tree->{$b}{'name'}} keys (%$tree);
  foreach my $super (@super_order) {
    next if ($all && $super == $all); # Skip the 3 layers structure, which leads to duplicated rows
    push @ids, $super;
    my $children = $tree->{$super}{'children'} || {};
    push @ids, sort {$children->{$a} cmp $children->{$b}} keys (%$children);
  }


  # Loop over the populations
  foreach my $pop_id (@ids) {

    my $svpf = $pop_data{$pop_id};

    next if (!$svpf);

    my ($row_class, $group_member);
    if ($svpf->name =~ /(\W+|_)ALL/ && $tree->{$pop_id}{'children'}) {
      $row_class = 'supergroup';
    }
    elsif ($tree->{$pop_id}{'children'}) {
      $row_class = 'subgroup';
    }
    elsif (scalar keys %$tree > 1) {
      $group_member = 1;
    }

    my @pop_parts = split(':',$svpf->name);
    my $pop_name  = (@pop_parts > 2) ? $pop_parts[$#pop_parts] : $pop_parts[0].':<b>'.$pop_parts[1].'</b>';
    my $pop_desc  = $svpf->description;
    my $pop_size  = $svpf->size;
    my $global_freq = sprintf("%.4f",$svpf->frequency);
    my $global_allele_count = 0;
    my $freqs_by_SO_term = $svpf->frequencies_by_class_SO_term;
    my $class_freq = '';
    foreach my $SO_term (sort(keys(%$freqs_by_SO_term))) {
      my $colour = $object->get_class_colour($SO_term);
      my $freq   = sprintf("%.4f",$freqs_by_SO_term->{$SO_term});

      my $allele_count = 0;
     
      # Loop over Sample IDs
      foreach my $sample_id (keys(%{$svpf->{samples_class}{$SO_term}})) {
        $allele_count += ($svpf->{samples_class}{$SO_term}{$sample_id} eq 'homozygous') ? 2 : 1;
      }
      $class_freq .= sprintf('<p style="margin-bottom:0px"><span class="structural-variation-allele" style="background-color:%s"></span>'.
                             '<span style="margin-bottom:2px">%s</span>: '.
                             '<span style="font-weight:bold">%s (%i)</span></p>',
                             $colour, $VARIATION_CLASSES{$SO_term}{'display_term'}, $freq, $allele_count);
      $global_allele_count += $allele_count;
    }

    if ($pop_desc) {
      $pop_desc = $self->strip_HTML($pop_desc);
      $pop_name = qq{<span class="_ht ht" title="$pop_desc">$pop_name</span>};
    }

    my $row = {
      pop_name => $group_member ? '&nbsp;&nbsp;'.$pop_name : $pop_name,
      pop_size => $pop_size,
      a_freqs  => $class_freq,
      freqs    => "$global_freq ($global_allele_count)"
    };

    $row->{'options'}{'class'} = $row_class if $row_class;

    push @rows, $row;
  }
  return \@rows;
}

sub extra_pop {

 my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};

  my %extra_pop;
  foreach my $pop ( @populations ) {
    my $id = $pop->dbID;
    $extra_pop{$id}{Name}       = $pop->name;
    $extra_pop{$id}{Size}       = $pop->size;
    $extra_pop{$id}{Description}= $pop->description;
  }
  return \%extra_pop;
}

1;
