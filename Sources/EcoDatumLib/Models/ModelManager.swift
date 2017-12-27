import Foundation
import Fluent
import Vapor

class ModelManager {
  
  let drop: Droplet
  
  init(_ drop: Droplet) throws {
    self.drop = drop
  }
  
  func getRootUser() throws -> User {
    
    guard let rootUserConfig = drop.config.wrapped.object?["app"]?["root-user"],
      let rootUserName = rootUserConfig["name"]?.string,
      let rootUserEmail = rootUserConfig["email"]?.string else {
        throw Abort(.expectationFailed)
    }
    
    guard let rootUser = try User.find(Constants.ROOT_USER_ID),
      rootUser.name == rootUserName,
      rootUser.email == rootUserEmail else {
        throw Abort(.expectationFailed)
    }
    
    return rootUser
    
  }
  
  func getRole(_ connection: Connection? = nil,
               name: Role.Name) throws -> Role {
    
    guard let role = try Role.makeQuery(connection)
      .filter(Role.Keys.name, .equals, name.rawValue)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    return role
    
  }
  
  func getAbioticFactor(_ connection: Connection? = nil,
                        name: AbioticFactor.Name) throws -> AbioticFactor {
    
    guard let abioticFactor = try AbioticFactor.makeQuery(connection)
      .filter(AbioticFactor.Keys.name, .equals, name.rawValue)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    return abioticFactor
    
  }
  
  func getMeasurementUnit(_ connection: Connection? = nil,
                          name: MeasurementUnit.Name) throws -> MeasurementUnit {
    
    guard let measurementUnit = try MeasurementUnit.makeQuery(connection)
      .filter(MeasurementUnit.Keys.name, .equals, name.rawValue)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    return measurementUnit
    
  }
  
  func getImageType(_ connection: Connection? = nil,
                    name: ImageType.Name) throws -> ImageType {
    
    guard let imageType = try ImageType.makeQuery(connection)
      .filter(ImageType.Keys.name, .equals, name.rawValue)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    return imageType
    
  }
  
  func createUser(_ connection: Connection? = nil,
                  name: String,
                  email: String,
                  password: String) throws -> User {
    
    let user = User(
      name: name,
      email: email,
      password: try hashPassword(password))
    try User.makeQuery(connection).save(user)
    
    return user
    
  }
  
  func findUser(_ connection: Connection? = nil,
                byUserId: Identifier) throws -> User? {
    return try User.makeQuery(connection).find(byUserId)
  }
  
  func findUser(_ connection: Connection? = nil,
                byEmail: String) throws -> User? {
    return try User.makeQuery(connection)
      .filter(User.Keys.email, .equals, byEmail)
      .first()
  }
  
  func findSurveyOwner(_ connection: Connection? = nil,
                       survey: Survey) throws -> User? {
    guard let user = try survey.user.get() else {
      throw Abort(.expectationFailed)
    }
    return user
  }
  
  func findMeasurementOwner(_ connection: Connection? = nil,
                            measurement: Measurement) throws -> User? {
    guard let survey = try measurement.survey.get(),
      let user = try findSurveyOwner(connection, survey: survey) else {
        throw Abort(.expectationFailed)
    }
    return user
  }
  
  func updateUser(_ connection: Connection? = nil,
                  user: User,
                  newName: String? = nil,
                  newEmail: String? = nil,
                  newPassword: String? = nil) throws -> User {
    
    try user.assertExists()
    
    if let name = newName {
      user.name = name
    }
    
    if let email = newEmail {
      user.email = email
    }
    
    if let password = newPassword {
      user.password = try hashPassword(password)
    }
    
    try User.makeQuery(connection).save(user)
    
    return user
    
  }
  
  func deleteUser(_ connection: Connection? = nil,
                  user: User) throws {
    try user.assertExists()
    try User.makeQuery(connection).delete(user)
  }
  
  func createOrganization(_ connection: Connection? = nil,
                          user: User,
                          name: String,
                          description: String? = nil,
                          code: String) throws -> Organization {
    
    guard code.utf8.count == Organization.CODE_LENGTH else {
      throw Abort(.expectationFailed)
    }
    
    let organization = Organization(
      name: name,
      description: description,
      code: code)
    try Organization.makeQuery(connection).save(organization)
    
    try _ = addUserToOrganization(connection,
                                  user: user,
                                  organization: organization,
                                  role: try getRole(name: .ADMINISTRATOR))
    
    return organization
    
  }
  
  func addUserToOrganization(_ connection: Connection? = nil,
                             user: User,
                             organization: Organization,
                             role: Role) throws -> UserOrganizationRole {
    
    let userId = try user.assertExists()
    let organizationId = try organization.assertExists()
    let roleId = try role.assertExists()
    
    let userOrganizationRole = UserOrganizationRole(
      userId: userId,
      organizationId: organizationId,
      roleId: roleId)
    try UserOrganizationRole.makeQuery(connection)
      .save(userOrganizationRole)
    
    return userOrganizationRole
    
  }
  
  func addUserToOrganization(_ connection: Connection? = nil,
                             user: User,
                             organization: Organization,
                             role: Role.Name) throws -> UserOrganizationRole {
    return try addUserToOrganization(
      connection,
      user: user,
      organization: organization,
      role: getRole(name: role))
  }
  
  func findOrganization(_ connection: Connection? = nil,
                        organizationId: Identifier) throws -> Organization? {
    return try Organization.makeQuery(connection).find(organizationId)
  }
  
  func findOrganization(_ connection: Connection? = nil,
                        site: Site) throws -> Organization? {
    try site.assertExists()
    return try findOrganization(connection, organizationId: site.organizationId)
  }
  
  func findOrganization(_ connection: Connection? = nil,
                        survey: Survey) throws -> Organization? {
    try survey.assertExists()
    guard let site = try survey.site.get() else {
      throw Abort(.expectationFailed)
    }
    return try findOrganization(connection, site: site)
  }
  
  func updateOrganization(_ connection: Connection? = nil,
                          organization: Organization,
                          newName: String? = nil,
                          newDescription: String? = nil) throws -> Organization {
    
    try organization.assertExists()
    
    if let name = newName {
      organization.name = name
    }
    
    if let description = newDescription {
      organization.description = description
    }
    
    try Organization.makeQuery(connection).save(organization)
    
    return organization
    
  }
  
  func deleteOrganization(_ connection: Connection? = nil,
                          organization: Organization) throws {
    try organization.assertExists()
    try Organization.makeQuery(connection).delete(organization)
  }
  
  func createSite(_ connection: Connection? = nil,
                  name: String,
                  latitude: Double,
                  longitude: Double,
                  altitude: Double?,
                  horizontalAccuracy: Double?,
                  verticalAccuracy: Double?,
                  user: User,
                  organization: Organization) throws -> Site {
    
    let userId = try user.assertExists()
    let organizationId = try organization.assertExists()
    let roleId = try getRole(connection, name: .ADMINISTRATOR).assertExists()
    
    guard let _ = try UserOrganizationRole.makeQuery(connection)
      .filter(UserOrganizationRole.Keys.organizationId, .equals, organizationId)
      .filter(UserOrganizationRole.Keys.roleId, .equals, roleId)
      .filter(UserOrganizationRole.Keys.userId, .equals, userId)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    let site = Site(name: name,
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    organizationId: organizationId,
                    userId: userId)
    try Site.makeQuery(connection).save(site)
    
    return site
    
  }
  
  func findSite(_ connection: Connection? = nil,
                siteId: Identifier) throws -> Site? {
    return try Site.makeQuery(connection).find(siteId)
  }
  
  func findSite(_ connection: Connection? = nil,
                survey: Survey) throws -> Site? {
    try survey.assertExists()
    return try findSite(connection, siteId: survey.siteId)
  }
  
  func updateSite(_ connection: Connection? = nil,
                  site: Site,
                  newName: String? = nil,
                  newLatitude: Double? = nil,
                  newLongitude: Double? = nil,
                  newAltitude: Double? = nil,
                  newHorizontalAccuracy: Double? = nil,
                  newVerticalAccuracy: Double? = nil) throws -> Site {
    
    try site.assertExists()
    
    if let name = newName {
      site.name = name
    }
    
    if let latitude = newLatitude {
      site.latitude = latitude
    }
    
    if let longitude = newLongitude {
      site.longitude = longitude
    }
    
    if let altitude = newAltitude {
      site.altitude = altitude
    }
    
    if let horizontalAccuracy = newHorizontalAccuracy {
      site.horizontalAccuracy = horizontalAccuracy
    }
    
    if let verticalAccuracy = newVerticalAccuracy {
      site.verticalAccuracy = verticalAccuracy
    }
    
    try Site.makeQuery(connection).save(site)
    
    return site
    
  }
  
  func deleteSite(_ connection: Connection? = nil,
                  site: Site) throws {
    try site.assertExists()
    try Site.makeQuery(connection).delete(site)
  }
  
  func createSurvey(_ connection: Connection? = nil,
                    date: Date,
                    site: Site,
                    user: User) throws -> Survey {
    
    let siteId = try site.assertExists()
    let organizationId = site.organizationId
    let userId = try user.assertExists()
    
    guard let _ = try UserOrganizationRole.makeQuery(connection)
      .filter(UserOrganizationRole.Keys.organizationId, .equals, organizationId)
      .filter(UserOrganizationRole.Keys.userId, .equals, userId)
      .first() else {
        throw Abort(.expectationFailed)
    }
    
    let survey = Survey(
      date: date,
      siteId: siteId,
      userId: userId)
    try Survey.makeQuery(connection).save(survey)
    
    return survey
    
  }
  
  func findSurvey(_ connection: Connection? = nil,
                  surveyId: Identifier) throws -> Survey? {
    return try Survey.makeQuery(connection).find(surveyId)
  }
  
  func deleteSurvey(_ connection: Connection? = nil,
                    survey: Survey) throws {
    try survey.assertExists()
    try Survey.makeQuery(connection).delete(survey)
  }
  
  func createMeasurement(_ connection: Connection? = nil,
                         value: Double,
                         abioticFactor: AbioticFactor,
                         measurementUnit: MeasurementUnit,
                         survey: Survey) throws -> Measurement {
    
    let abioticFactorId = try abioticFactor.assertExists()
    let measurementUnitId = try measurementUnit.assertExists()
    let surveyId = try survey.assertExists()
    
    guard let organizationId = try findOrganization(connection, survey: survey)?.id,
      let _ = try UserOrganizationRole.makeQuery(connection)
        .filter(UserOrganizationRole.Keys.organizationId, .equals, organizationId)
        .filter(UserOrganizationRole.Keys.userId, .equals, survey.userId)
        .first() else {
          throw Abort(.expectationFailed)
    }
    
    let measurement = Measurement(
      value: value,
      abioticFactorId: abioticFactorId,
      measurementUnitId: measurementUnitId,
      surveyId: surveyId)
    try Measurement.makeQuery(connection).save(measurement)
    
    return measurement
    
  }
  
  func createMeasurement(_ connection: Connection? = nil,
                         value: Double,
                         abioticFactor abioticFactorName: AbioticFactor.Name,
                         measurementUnit measurementUnitName: MeasurementUnit.Name,
                         survey: Survey) throws -> Measurement {
  
    return try createMeasurement(
      connection,
      value: value,
      abioticFactor: try getAbioticFactor(name: abioticFactorName),
      measurementUnit: try getMeasurementUnit(name: measurementUnitName),
      survey: survey)
    
  }
  
  func findMeasurement(_ connection: Connection? = nil,
                       measurementId: Identifier) throws -> Measurement? {
    return try Measurement.makeQuery(connection).find(measurementId)
  }
  
  func updateMeasurement(_ connection: Connection? = nil,
                         measurement: Measurement,
                         newValue: Double? = nil,
                         newAbioticFactor: AbioticFactor? = nil,
                         newMeasurementUnit: MeasurementUnit? = nil) throws -> Measurement {
    
    try measurement.assertExists()
    
    if let value = newValue {
      measurement.value = value
    }
    
    if let abioticFactorId = try newAbioticFactor?.assertExists() {
      measurement.abioticFactorId = abioticFactorId
    }
    
    if let measurementUnitId = try newMeasurementUnit?.assertExists() {
      measurement.measurementUnitId = measurementUnitId
    }
    
    try Measurement.makeQuery(connection).save(measurement)
    
    return measurement
    
  }
  
  func deleteMeasurement(_ connection: Connection? = nil,
                         measurement: Measurement) throws {
    try measurement.assertExists()
    try Measurement.makeQuery(connection).delete(measurement)
  }
  
  func createNote(_ connection: Connection? = nil,
                  text: String,
                  survey: Survey) throws -> Note {
    
    let surveyId = try survey.assertExists()
    
    guard let organizationId = try findOrganization(connection, survey: survey)?.id,
      let _ = try UserOrganizationRole.makeQuery(connection)
        .filter(UserOrganizationRole.Keys.organizationId, .equals, organizationId)
        .filter(UserOrganizationRole.Keys.userId, .equals, survey.userId)
        .first() else {
          throw Abort(.expectationFailed)
    }
    
    let note = Note(text: text, surveyId: surveyId)
    try Note.makeQuery(connection).save(note)
    
    return note
    
  }
  
  func findNote(_ connection: Connection? = nil,
                noteId: Identifier) throws -> Note? {
    return try Note.makeQuery(connection).find(noteId)
  }
  
  func updateNote(_ connection: Connection? = nil,
                  note: Note,
                  newText: String) throws -> Note {
    
    try note.assertExists()
    
    note.text = newText
    try Note.makeQuery(connection).save(note)
    
    return note
    
  }
  
  func deleteNote(_ connection: Connection? = nil,
                  note: Note) throws {
    try note.assertExists()
    try Note.makeQuery(connection).delete(note)
  }
  
  func createImage(_ connection: Connection? = nil,
                   base64Encoded: String,
                   description: String? = nil,
                   imageType: ImageType,
                   survey: Survey) throws -> Image {
    
    let imageTypeId = try imageType.assertExists()
    let surveyId = try survey.assertExists()
    
    guard let organizationId = try findOrganization(connection, survey: survey)?.id,
      let _ = try UserOrganizationRole.makeQuery(connection)
        .filter(UserOrganizationRole.Keys.organizationId, .equals, organizationId)
        .filter(UserOrganizationRole.Keys.userId, .equals, survey.userId)
        .first() else {
          throw Abort(.expectationFailed)
    }
    
    let image = Image(
      base64Encoded: base64Encoded,
      description: description,
      imageTypeId: imageTypeId,
      surveyId: surveyId)
    try Image.makeQuery(connection).save(image)
    
    return image
    
  }
  
  func createImage(_ connection: Connection? = nil,
                   base64Encoded: String,
                   description: String? = nil,
                   imageType imageTypeName: ImageType.Name,
                   survey: Survey) throws -> Image {
  
    return try createImage(
      connection,
      base64Encoded: base64Encoded,
      description: description,
      imageType: try getImageType(name: imageTypeName),
      survey: survey)
    
  }
  
  func findImage(_ connection: Connection? = nil,
                 imageId: Int) throws -> Image? {
    return try Image.makeQuery(connection).find(imageId)
  }
  
  func updateImage(_ connection: Connection? = nil,
                   image: Image,
                   newBase64Encoded: String? = nil,
                   newDescription: String? = nil,
                   newImageType: ImageType? = nil) throws -> Image? {
    
    try image.assertExists()
    
    if let base64Encoded = newBase64Encoded {
      image.base64Encoded = base64Encoded
    }
  
    if let description = newDescription {
      image.description = description
    }
    
    if let imageTypeId = try newImageType?.assertExists() {
      image.imageTypeId = imageTypeId
    }
    
    try Image.makeQuery(connection).save(image)
    
    return image
    
  }
  
  func deleteImage(_ connection: Connection? = nil,
                   image: Image) throws {
    try image.assertExists()
    try Image.makeQuery(connection).delete(image)
  }
  
  private func hashPassword(_ password: String) throws -> String {
    return try drop.hash.make(password.makeBytes()).makeString()
  }
  
}

