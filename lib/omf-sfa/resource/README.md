@startuml
hide members

OResource <|-- OComponent
OResource <|-- OGroup
OGroup <|-- OAccount
OResource <|-- OLease
OResource <|-- OProject
OResource <|-- User
@enduml

@startuml
hide members

OGroup "*" -- "*" OComponent : contains >
OGroup "1" -- "*" OGroup : contains >
OComponent "*" -- "1" OAccount : charged_to >
OComponent "1" -- "*" OComponent : provided_by >
OLease "*" -- "0,1" OComponent: < leased_by 
OProject "1" -- "1" OAccount : account >
OProject "*" -- "*" User: member > 
OAccount "*" -- "1" OLease : holds_lease >
OProject "*" -- "1" OProject: parent_project > 
@enduml