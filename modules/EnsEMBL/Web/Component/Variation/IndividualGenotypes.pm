package EnsEMBL::Web::Component::Variation::IndividualGenotypes;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';

  ## first check we have a location
  unless ($object->core_objects->location ){
   $html = "<p>You must select a location from the panel above to see this information</p>";
   return $html;
  }


  ## return if no data
  my %ind_data = %{ $object->individual_table };
  unless (%ind_data) {
    $html = "<p>No individual genotypes for this SNP</p>";
    return $html;
  }

  ## if data continue
  my @rows;
  my $flag_children = 0;

  foreach my $ind_id (sort { $ind_data{$a}{Name} cmp $ind_data{$b}{Name}} keys %ind_data) {
    my %ind_row;
    my $genotype = $ind_data{$ind_id}{Genotypes};
    next if $genotype eq '(indeterminate)';

    # Parents -----------------------------------------------------------------
    my $father = _format_parent($object, $ind_data{$ind_id}{Father} );
    my $mother = _format_parent($object, $ind_data{$ind_id}{Mother} );


    # Name, Gender, Desc ------------------------------------------------------
    my $description = uc($ind_data{$ind_id}{Description});
    my @populations = map {_pop_url( $object, $_->{Name}, $_->{Link} ) } @{ $ind_data{$ind_id}{Population} };

    my $pop_string = join ", ", @populations;
    my %tmp_row = ();

     $tmp_row{'Individual'}  = "<small>".$ind_data{$ind_id}{Name}."<br />(".$ind_data{$ind_id}{Gender}.")</small>";
     $tmp_row{'Genotype'}    = "<small>$genotype</small>";
     $tmp_row{'Description'} = "<small>".($description ||"-") ."</small>";
     $tmp_row{'Populations'} = "<small>".($pop_string ||"-") ."</small>";
     $tmp_row{'Father'}      = "<small>".($father||"-") ."</small>";
     $tmp_row{'Mother'}      = "<small>".($mother ||"-") ."</small>";
 

    #  Children  -------------------------------------------------------------
    my $children =  $ind_data{$ind_id}{Children};
    $tmp_row{'Children'} = "-";

     my @children = map {"<small>$_: ".$children->{$_}[0]."</small>"} (keys %$children);

    if (@children) {
      $tmp_row{'Children'} = join "<br />", @children;
      $flag_children = 1;
    }

   push (@rows, \%tmp_row);
 } 
  
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns (
   {key  =>"Individual",   title => "Individual<br />(gender)"},
   {key  =>"Genotype",    title => "Genotype<br />(forward strand)"},
   {key  =>"Description", title => "Description"},
   {key  =>"Populations", title => "Populations", width=>"250"},
   {key  =>"Father",      title => "Father"},
   {key  =>"Mother",      title => "Mother"} );

  if ($flag_children) {$table->add_columns ({ key=>"Children", title =>"Children"}) ; }
  
  foreach my $row (@rows){
    $table->add_row($row);
  }

  return $table->render;
}

sub _format_parent {

  ### Internal_individual_table
  ### Arg1        : data object
  ### Arg2        : parent data
  ### Example     : format_parent(
  ###                $object->parent($object, $ind_genotype,"father") );
  ### Description : Formats output
  ### Returns  string

  my $object        = shift;
  my $parent_data = shift;
  return "-" unless $parent_data;

  my $string = $parent_data->{Name};
  return $string;
}

sub _pop_url {

   ### Arg1        : data object
   ### Arg2        : Population name (to be displayed)
   ### Arg3        : dbSNP population ID (variable to be linked to)
   ### Example     : _pop_url($object, $pop_name, $pop_dbSNPID);
   ### Description : makes pop_name into a link
   ### Returns  string

  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP',$pop_dbSNP->[0] );
}


1;
