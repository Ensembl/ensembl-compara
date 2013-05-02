

package EnsEMBL::Web::Component::Variation::Publication;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  
  my $data = $object->get_citation_data;
  
  return $self->_info('We do not have any citation data for this variation') unless scalar @$data;
  

  my ($table_rows ) = $self->table_data($data);
  my $table         = $self->new_table([], [], { data_table => 1 });
   

  $table->add_columns(
    { key => 'pmid', title => 'PMID', align => 'left', sort => 'html' },  
    { key => 'title', title => 'Title', align => 'left', sort => 'html' },  
    { key => 'author',  title => 'Author(s)',     align => 'left', sort => 'html' },
    { key => 'text', title => 'Full text', align => 'left', sort => 'html' },  
  );
  
  foreach my $row (@{$table_rows}){  $table->add_rows($row);}
  return $table->render;
};


sub table_data { 
  my ($self, $citation_data) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;

  my $epmc_url = 'http://europepmc.org/articles/';
  my $pm_url   = 'http://www.ncbi.nlm.nih.gov/pubmed/';

  my @data_rows;
                 
                 
  foreach my $cit (@$citation_data) { 

    my $row = {
      pmid    => defined $cit->pmid() ? "<a href=\"" . $pm_url . $cit->pmid() . "\">" .$cit->pmid() . "</a>" : undef,
      title   => $cit->title(),
      author  => $cit->authors(),
      text    => defined $cit->pmcid() ? "<a href=\"" . $epmc_url . $cit->pmcid() . "\">" . $cit->pmcid() . "</a>" : undef,
    };
  
    
    push @data_rows, $row;

  } 

  return \@data_rows;
}


1;
