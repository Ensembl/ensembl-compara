=head1 NAME

Bio::Tools::Run::Search::ensembl_wublastn - Ensembl BLASTN searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::EnsemblBlast
  see Bio::Tools::Run::Search::wublastn

=head1 DESCRIPTION

Multiple inheretance object combining
Bio::Tools::Run::Search::EnsemblBlast and
Bio::Tools::Run::Search::wublastn

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ensembl_wublastn;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::EnsemblBlast;
use Bio::Tools::Run::Search::wublastn;

@ISA = qw( Bio::Tools::Run::Search::EnsemblBlast 
           Bio::Tools::Run::Search::wublastn );

BEGIN{
}

# Nastyness to get round multiple inheretance problems.
sub program_name{return Bio::Tools::Run::Search::wublastn::program_name(@_)}
sub algorithm   {return Bio::Tools::Run::Search::wublastn::algorithm(@_)}
sub version     {return Bio::Tools::Run::Search::wublastn::version(@_)}
sub parameter_options{
  return Bio::Tools::Run::Search::wublastn::parameter_options(@_)
}

#----------------------------------------------------------------------
1;
