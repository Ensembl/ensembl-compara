=head1 NAME

Bio::Tools::Run::Search::ensembl_wutblastn - Ensembl TBLASTN searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::EnsemblBlast
  see Bio::Tools::Run::Search::wutblastn

=head1 DESCRIPTION

Multiple inheretance object combining
Bio::Tools::Run::Search::EnsemblBlast and
Bio::Tools::Run::Search::wutblastn

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ensembl_wutblastn;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::EnsemblBlast;
use Bio::Tools::Run::Search::wutblastn;

@ISA = qw( Bio::Tools::Run::Search::EnsemblBlast 
           Bio::Tools::Run::Search::wutblastn );

BEGIN{
}

# Nastyness to get round multiple inheretance problems.
sub program_name{return Bio::Tools::Run::Search::wutblastn::program_name(@_)}
sub algorithm   {return Bio::Tools::Run::Search::wutblastn::algorithm(@_)}
sub version     {return Bio::Tools::Run::Search::wutblastn::version(@_)}
sub parameter_options{
  return Bio::Tools::Run::Search::wutblastn::parameter_options(@_)
}

#----------------------------------------------------------------------
1;
