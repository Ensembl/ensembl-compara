

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
  
  return $self->_info('No citation data is available') unless scalar @$data;
  
  my $html = ('<b>' . $object->name() .' is mentioned in the following publications</b>'); 

  my ($table_rows ) = $self->table_data($data);
  my $table         = $self->new_table([], [], { data_table => 1 });
   

  $table->add_columns(   
    { key => 'pmid',   title => 'PMID',      align => 'left', sort => 'html' },  
    { key => 'title',  title => 'Title',     align => 'left', sort => 'html' },  
    { key => 'author', title => 'Author(s)', align => 'left', sort => 'html' },
    { key => 'text',   title => 'Full text', align => 'left', sort => 'html' },  
    { key => 'year',   title => 'Year',      align => 'left', sort => 'html' },  
  );

  $table->add_columns( { key => 'ucsc',   title => 'UCSC', align => 'left', sort => 'html' }) if $self->hub->species eq 'Homo_sapiens';
  foreach my $row (@{$table_rows}){  $table->add_rows($row);}

  $html .=  $table->render;
  return $html;
};


sub table_data { 
  my ($self, $citation_data) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;

  my $ucsc_url = 'http://genome.ucsc.edu/cgi-bin/hgc?r=0&l=0&c=0&o=-1&t=0&g=pubsMarkerSnp&i='; ## TESTURL

  my @data_rows;
                 
                 
  foreach my $cit (@$citation_data) { 
      
      my $row = {
	  year    => $cit->year(),
	  pmid    => defined $cit->pmid() ? $hub->get_ExtURL_link($cit->pmid(), "PUBMED", $cit->pmid()) : undef,
	  title   => $cit->title(),
	  author  => $cit->authors(),
	  text    => defined $cit->pmcid() ? $hub->get_ExtURL_link($cit->pmcid(), "EPMC", $cit->pmcid()) : undef,
	  ucsc    => defined $cit->ucsc_id() ? "<a href=\"" . $ucsc_url . $object->name() ."&pubsFilterExtId=". $cit->ucsc_id() . "\">View</a>" : undef 

     
    };
  
    push @data_rows, $row;

  } 

  return \@data_rows;
}


1;
