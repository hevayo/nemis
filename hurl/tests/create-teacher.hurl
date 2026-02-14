# =============================================================================
# Create Teacher — Full Integration Test
# Expects `token` variable injected by run.sh
# =============================================================================

# Step 1: Check NIC does not already exist
GET {{gateway_url}}/teachers/check-nic/{{nic}}
Authorization: Bearer {{token}}
[Options]
insecure: true

HTTP 200

# Step 2: Create teacher
POST {{gateway_url}}/teacher-create
Authorization: Bearer {{token}}
Content-Type: application/json
[Options]
insecure: true
{
  "nic": "{{nic}}",
  "is_new_registration": true,
  "titleId": "T01",
  "fullName": "Test Teacher User",
  "dateOfBirth": "1990-01-15T00:00:00Z",
  "genderId": "G01",
  "religionId": "R01",
  "ethnicityId": "E01",
  "civilStatusId": "C01",
  "bloodGroupId": "B01",
  "healthCondition": 1,
  "healthConditionDescription": null,
  "districtId": "DIS001",
  "gnDivisionId": "GND01766",
  "dsOfficeId": "DSO0056",
  "email": "{{email}}",
  "contact": "0771234567",
  "addressLine1": "123 Test Street",
  "addressLine2": "Test City",
  "addressLine3": null,
  "postalCode": "10100",
  "firstAppointmentCategory": "TCAT0001",
  "firstAppointmentDate": "2020-01-01T00:00:00Z",
  "firstAppointmentLetter": "APT/2020/001",
  "firstAppointmentService": "SER001",
  "firstAppointmentRank": "RANK001",
  "firstAppointmentType": "TCHTYPE001",
  "firstAppointmentSubject": "ASUB0034",
  "firstAppointmentMedium": "MED01",
  "firstAppointmentTeachingSubject": "SUB0048",
  "firstAppointmentZone": "ZEO0000001",
  "firstAppointmentInstCategory": "ICID001",
  "firstAppointmentInstitution": "INST00001",
  "firstAppointmentPosition": "POS001",
  "currentAppointmentRegType": "Permanent",
  "currentAppointmentDate": "2020-01-01T00:00:00Z",
  "currentAppointmentLetter": "APT/2020/001",
  "currentAppointmentService": "SER001",
  "currentAppointmentRank": "RANK001",
  "currentAppointmentSubject": "ASUB0034",
  "currentAppointmentZone": "ZEO0000001",
  "currentAppointmentInstCategory": "ICID001",
  "currentAppointmentInstitution": "INST00001",
  "currentAppointmentPosition": "POS001"
}

HTTP 201
[Asserts]
jsonpath "$.status" == "success"
jsonpath "$.people_id" exists
[Captures]
people_id: jsonpath "$.people_id"

# Step 3: Verify teacher now exists in NEMIS
GET {{gateway_url}}/teachers/check-nic/{{nic}}
Authorization: Bearer {{token}}
[Options]
insecure: true

HTTP 200
[Asserts]
jsonpath "$.message" == "Teacher nic not available"

# Step 4: Verify user was created in IS (SCIM2 lookup with Basic auth)
GET {{is_url}}/scim2/Users?filter=emails+eq+{{email}}
[Options]
insecure: true
[BasicAuth]
{{is_admin_user}}: {{is_admin_password}}

HTTP 200
[Asserts]
jsonpath "$.totalResults" >= 1
