table base_age
"Age of Base"
(
string  chrom;       "Reference sequence chromosome or scaffold"
uint    chromStart;  "Start position of feature on chromosome"
uint    chromEnd;    "End position of feature on chromosome"
string  taxon_name;  "Oldest taxon that possess this base"
uint    age;         "Normalised substitution-based age (between 0 -species level- and 1000 -root of all aligned species-)"
string  colour;      "Colour representation of the age"
)
